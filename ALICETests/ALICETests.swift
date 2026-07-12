//
//  ALICETests.swift
//  ALICE
//
//  Unit tests for core logic: pointer tag parsing, model selection,
//  configuration, and voice state.
//

import Testing
@testable import ALICE

struct ALICETests {

    // MARK: - Pointer Tag Parser

    @Test func parseValidPointerTag() async throws {
        let text = "Click the blue button [POINT:150,300:Submit Button:1] to continue."
        let tag = PointerTagParser.parse(from: text)
        #expect(tag != nil)
        #expect(tag?.x == 150)
        #expect(tag?.y == 300)
        #expect(tag?.label == "Submit Button")
        #expect(tag?.displayIndex == 1)
    }

    @Test func parsePointerTagWithDecimals() async throws {
        let text = "Look at [POINT:150.5,300.75:Menu:2]"
        let tag = PointerTagParser.parse(from: text)
        #expect(tag != nil)
        #expect(tag?.x == 150.5)
        #expect(tag?.y == 300.75)
    }

    @Test func parseNoPointerTagReturnsNil() async throws {
        let text = "This is a conceptual answer with no pointing tag."
        let tag = PointerTagParser.parse(from: text)
        #expect(tag == nil)
    }

    @Test func parseMultipleTagsReturnsFirst() async throws {
        let text = "[POINT:10,20:First:1] and [POINT:30,40:Second:1]"
        let tag = PointerTagParser.parse(from: text)
        #expect(tag?.x == 10)
        #expect(tag?.label == "First")
    }

    @Test func parseEmptyLabelReturnsNil() async throws {
        // ponytail: empty label should not match — [^:]+ requires at least one char
        let text = "[POINT:10,20::1]"
        let tag = PointerTagParser.parse(from: text)
        #expect(tag == nil)
    }

    // MARK: - AI Model

    @Test func allModelsHaveDisplayNames() async throws {
        for model in AIModel.allCases {
            #expect(!model.displayName.isEmpty)
        }
    }

    @Test func modelRawValuesAreAPIIdentifiers() async throws {
        #expect(AIModel.claudeSonnet.rawValue == "claude-sonnet-4-6")
        #expect(AIModel.claudeOpus.rawValue == "claude-opus-4-6")
        #expect(AIModel.gpt52.rawValue == "gpt-5.2-2025-12-11")
    }

    @Test func modelCountIsThree() async throws {
        #expect(AIModel.allCases.count == 3)
    }

    // MARK: - Voice State

    @Test func voiceStateEquality() async throws {
        #expect(VoiceState.idle == VoiceState.idle)
        #expect(VoiceState.listening != VoiceState.thinking)
    }

    @Test func voiceStateHasFourCases() async throws {
        // ponytail: ensure all states exist
        let states: [VoiceState] = [.idle, .listening, .thinking, .speaking]
        #expect(states.count == 4)
    }

    // MARK: - Pointer Tag Structure

    @Test func pointerTagHasAllFields() async throws {
        let tag = PointerTag(x: 100, y: 200, label: "Button", displayIndex: 1)
        #expect(tag.x == 100)
        #expect(tag.y == 200)
        #expect(tag.label == "Button")
        #expect(tag.displayIndex == 1)
    }
}