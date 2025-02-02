//
//  PortalsPluginTests.swift
//  PortalsPluginTests
//
//  Created by Thomas Vidas on 7/13/21.
//

import XCTest
import IonicPortals
import Capacitor
import Combine

class PortalsPluginTests: XCTestCase {
    func test_topicPublisher__when_SubscriptionResults_are_published__they_are_emitted_to_downstream_subscribers() {
        var results: [SubscriptionResult] = []
        var cancellables = Set<AnyCancellable>()
        let topic = "test:result"
       
        // SUT
        PortalsPlugin.publisher(for: topic)
            .sink { results.append($0) }
            .store(in: &cancellables)
        
        PortalsPlugin.publish(topic, 1)
        XCTAssertEqual(results.count, 1)
        
        PortalsPlugin.publish(topic, 2)
        XCTAssertEqual(results.count, 2)
        
        PortalsPlugin.publish(topic, 3)
        XCTAssertEqual(results.count, 3)
    }
    
    func test_topicPublisher__when_data_operator_is_called__only_the_data_is_emitted_to_downstream_subscribers() {
        var results: [JSValue] = []
        var cancellables = Set<AnyCancellable>()
        let topic = "test:number:data"
        
        // SUT
        PortalsPlugin.publisher(for: topic)
            .data()
            .sink { results.append($0) }
            .store(in: &cancellables)
        
        PortalsPlugin.publish(topic, 1)
        PortalsPlugin.publish(topic, 2)
        PortalsPlugin.publish(topic, 3)
        
        XCTAssertEqual(results.count, 3)
    }
    
    func test_topicPublisher_data_as_operator__when_cast_as_a_valid_type__then_values_are_not_nil() {
        var results: [Int?] = []
        var cancellables = Set<AnyCancellable>()
        let topic = "test:number:dataAs"
        
        // SUT
        PortalsPlugin.publisher(for: topic)
            .data(as: Int.self)
            .sink { results.append($0) }
            .store(in: &cancellables)
        
        PortalsPlugin.publish(topic, 1)
        XCTAssertEqual(results, [1])
        
        PortalsPlugin.publish(topic, 2)
        XCTAssertEqual(results, [1, 2])
        
        PortalsPlugin.publish(topic, 3)
        XCTAssertEqual(results, [1, 2, 3])
    }
    
    func test_topicPublisher_data_as_operator__when_cast_as_an_invalid_type__then_downstream_values_are_nil() {
        var results: [Int?] = []
        var cancellables = Set<AnyCancellable>()
        let topic = "test:number:dataAs"
        
        // SUT
        PortalsPlugin.publisher(for: topic)
            .data(as: Int.self)
            .sink { results.append($0) }
            .store(in: &cancellables)
        
        PortalsPlugin.publish(topic, "hello")
        XCTAssertEqual(results, [nil])
        
        PortalsPlugin.publish(topic, 59.03)
        XCTAssertEqual(results, [nil, nil])
        
        PortalsPlugin.publish(topic, true)
        XCTAssertEqual(results, [nil, nil, nil])
    }
    
    func test_topicPublisher_data_as_operator__when_receiving_heterogenous_data__then_types_not_matching_the_cast_are_nil() {
        var results: [Int?] = []
        var cancellables = Set<AnyCancellable>()
        let topic = "test:number:dataAs"
        
        // SUT
        PortalsPlugin.publisher(for: topic)
            .data(as: Int.self)
            .sink { results.append($0) }
            .store(in: &cancellables)
        
        PortalsPlugin.publish(topic, 1)
        XCTAssertEqual(results, [1])
        
        PortalsPlugin.publish(topic, 59.03)
        XCTAssertEqual(results, [1, nil])
        
        PortalsPlugin.publish(topic, true)
        XCTAssertEqual(results, [1, nil, nil])
    }
    
    func test_topicPublisher_tryData_as_operator__when_a_valid_type_is_cast__then_no_error_is_emitted_downstream() {
        var results: [Int] = []
        var cancellables = Set<AnyCancellable>()
        let topic = "test:number:tryDataAs:success"
        
        // SUT
        PortalsPlugin.publisher(for: topic)
            .tryData(as: Int.self)
            .assertNoFailure()
            .sink { results.append($0) }
            .store(in: &cancellables)
       
        PortalsPlugin.publish(topic, 1)
        
        XCTAssertEqual(results, [1])
    }
    
    func test_topicPublisher_tryData_as_operator__when_an_invalid_type_is_cast__then_an_error_is_emitted_and_the_publisher_completes() {
        var results: [Int] = []
        var cancellables = Set<AnyCancellable>()
        var completed = false
        let topic = "test:number:tryDataAs:failure"
        
        // SUT
        PortalsPlugin.publisher(for: topic)
            .tryData(as: Int.self)
            .catch { error in
                Just(-1)
            }
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { results.append($0) }
            )
            .store(in: &cancellables)
        
        PortalsPlugin.publish(topic, "hello")
        
        XCTAssertEqual(results, [-1])
        XCTAssertTrue(completed)
    }
    
    struct MagicTheGatheringCard: Codable, Equatable {
        var name: String
        var manaCost: String
        var convertedManaCost: Int8
    }
    
    func test_topicPublisher_decodeData_operator__when_well_formed_data_is_received__then_the_value_is_decoded_and_emitted_downstream() throws {
        var results: [MagicTheGatheringCard] = []
        var cancellables = Set<AnyCancellable>()
        let topic = "test:decoding:wellformed"
        
        let card = MagicTheGatheringCard(
            name: "Counterspell",
            manaCost: "{U}{U}",
            convertedManaCost: 2
        )
        
        // SUT
        PortalsPlugin.publisher(for: topic)
            .decodeData(MagicTheGatheringCard.self, decoder: JSONDecoder())
            .assertNoFailure()
            .sink { results.append($0) }
            .store(in: &cancellables)
        
        let jsObject = try JSONEncoder().encodeJSObject(card)
        PortalsPlugin.publish(topic, jsObject)
        
        XCTAssertEqual(results, [card])
    }
    
    func test_topicPublisher_decodeData_operator__when_malformed_data_is_received__then_an_error_is_emitted_downstream_and_the_publisher_completes() {
        var results: [MagicTheGatheringCard] = []
        var cancellables = Set<AnyCancellable>()
        var completed = false
        let topic = "test:decoding:malformed"
        
        let emptyCard = MagicTheGatheringCard(name: "", manaCost: "", convertedManaCost: 0)
        
        // SUT
        PortalsPlugin.publisher(for: topic)
            .decodeData(MagicTheGatheringCard.self, decoder: JSONDecoder())
            .replaceError(with: emptyCard)
            .sink(
                receiveCompletion: { _ in completed = true },
                receiveValue: { results.append($0) }
            )
            .store(in: &cancellables)
        
        PortalsPlugin.publish(topic, 99.82)
        
        XCTAssertEqual(results, [emptyCard])
        XCTAssertTrue(completed)
    }
    
    #if compiler(>=5.6)
    func test_asyncSubscribe__when_values_are_published__they_are_able_to_be_manipulated_with_async_sequence_apis() async {
        let sut = Task {
            await PortalsPlugin.subscribe("test:asyncstream")
                .map { $0.data }
                .prefix(2)
                .first { _ in true }
        }
        
        Task {
            // For whatever reason, the publish method is consistently
            // being called first. In practice, it is extremely unlikely that
            // subscribers and publishers will be racing at the level of nanoseconds
            // to actually register and publish.
            try await Task.sleep(nanoseconds: 1)
            PortalsPlugin.publish("test:asyncstream", 1)
            PortalsPlugin.publish("test:asyncstream", 2)
        }
        
        guard let firstValue = await sut.value as? Int else {
            XCTFail("Awaited task value was not able to be cast as an Int")
            return
        }
        
        XCTAssertEqual(firstValue, 1)
    }
    #endif
}
