import XCTest
import Alamofire
import RQNetworking

@MainActor
final class RQRetryTests: XCTestCase {
    func testRequestLevelRetryConfigOverridesDefault() {
        let interceptor = RQRetryInterceptor(defaultRetryConfiguration: .aggressive)
        let overrideConfig = RQRetryConfiguration(
            maxRetryCount: 0,
            delayStrategy: .fixed(0),
            retryCondition: .always
        )
        interceptor.retryConfigurationProvider = { _ in overrideConfig }

        let session = Session(configuration: .ephemeral, startRequestsImmediately: false)
        let request = session.request("https://example.com")

        let expectation = self.expectation(description: "Retry result received")
        request.onURLRequestCreation(on: .global(qos: .userInitiated)) { _ in
            interceptor.retry(request, for: session, dueTo: NSError(domain: "test", code: 1)) { result in
                switch result {
                case .doNotRetry:
                    break
                default:
                    XCTFail("Expected no retry when request-level config overrides default")
                }
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1.0)
    }

    func testStatusCodesConditionUsesResponse() {
        let condition = RQRetryCondition.statusCodes([500, 502])
        let url = URL(string: "https://example.com")!
        let request = URLRequest(url: url)
        let response = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)

        let shouldRetry = condition.shouldRetry(
            error: NSError(domain: "test", code: 0),
            request: request,
            response: response
        )

        XCTAssertTrue(shouldRetry)
    }

    func testDefaultConditionMatchesTimeoutAndServerError() {
        let condition = RQRetryCondition.default
        let url = URL(string: "https://example.com")!
        let request = URLRequest(url: url)

        let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)
        XCTAssertTrue(condition.shouldRetry(error: NSError(domain: "test", code: 0), request: request, response: response))

        XCTAssertTrue(condition.shouldRetry(error: RQNetworkError.timeout, request: request, response: nil))

        let urlError = URLError(.timedOut)
        XCTAssertTrue(condition.shouldRetry(error: RQNetworkError.requestFailed(urlError), request: request, response: nil))
    }
}
