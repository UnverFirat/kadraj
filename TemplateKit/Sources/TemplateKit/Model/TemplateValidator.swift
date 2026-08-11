import Foundation

public enum TemplateValidationError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(Int)
    case invalidPaletteColor(role: String, value: String)
    case unknownColorRole(layerID: String, role: String)
    case duplicateLayerID(String)
    case duplicateSlotIndex(Int)
    case multipleVideoSlots
    case invalidTiming(layerID: String)
    case missingEnglishName
    case missingDuration
    case scenesRequireSchemaV2
    case emptyScenes
    case duplicateSceneID(String)
    case invalidSceneDuration(sceneID: String)
    case invalidTransition(sceneID: String)
    case tooManyVideoSlotsInScene(sceneID: String)

    public var description: String {
        switch self {
        case .unsupportedSchemaVersion(let v):
            return "Unsupported schemaVersion \(v) (supported: \(Template.supportedSchemaVersions))"
        case .invalidPaletteColor(let role, let value):
            return "Palette role '\(role)' has invalid color '\(value)'"
        case .unknownColorRole(let layerID, let role):
            return "Layer '\(layerID)' references unknown color role '\(role)'"
        case .duplicateLayerID(let id):
            return "Duplicate layer id '\(id)'"
        case .duplicateSlotIndex(let index):
            return "Duplicate slotIndex \(index)"
        case .multipleVideoSlots:
            return "Single-scene templates allow at most one video slot (v1 engine path)"
        case .invalidTiming(let layerID):
            return "Layer '\(layerID)' has timing outside its scene/template duration"
        case .missingEnglishName:
            return "Template name must include an 'en' entry"
        case .missingDuration:
            return "Templates without scenes must declare 'duration'"
        case .scenesRequireSchemaV2:
            return "'scenes' requires schemaVersion >= 2"
        case .emptyScenes:
            return "'scenes' must contain at least one scene"
        case .duplicateSceneID(let id):
            return "Duplicate scene id '\(id)'"
        case .invalidSceneDuration(let sceneID):
            return "Scene '\(sceneID)' must have duration > 0"
        case .invalidTransition(let sceneID):
            return "Scene '\(sceneID)' transition must satisfy 0 <= duration <= half of both adjacent scenes"
        case .tooManyVideoSlotsInScene(let sceneID):
            return "Scene '\(sceneID)' exceeds 4 simultaneous video-capable slots"
        }
    }
}

/// Şablon yüklenirken (indirme sonrası, galeriye girmeden) çalışır.
/// Amaç: bozuk şablonun editöre/exporter'a hiç ulaşmaması.
public enum TemplateValidator {
    /// Sahne başına eşzamanlı video-alabilen slot limiti (compositor performansı).
    public static let maxVideoSlotsPerScene = 4

    public static func validate(_ template: Template) throws {
        guard Template.supportedSchemaVersions.contains(template.schemaVersion) else {
            throw TemplateValidationError.unsupportedSchemaVersion(template.schemaVersion)
        }
        guard template.name.values["en"] != nil else {
            throw TemplateValidationError.missingEnglishName
        }

        for (role, value) in template.palette where RGBAColor(hex: value) == nil {
            throw TemplateValidationError.invalidPaletteColor(role: role, value: value)
        }

        var layerIDs = Set<String>()
        var slotIndexes = Set<Int>()

        if let scenes = template.scenes {
            guard template.schemaVersion >= 2 else {
                throw TemplateValidationError.scenesRequireSchemaV2
            }
            guard !scenes.isEmpty else {
                throw TemplateValidationError.emptyScenes
            }

            var sceneIDs = Set<String>()
            for (index, scene) in scenes.enumerated() {
                guard sceneIDs.insert(scene.id).inserted else {
                    throw TemplateValidationError.duplicateSceneID(scene.id)
                }
                guard scene.duration > 0 else {
                    throw TemplateValidationError.invalidSceneDuration(sceneID: scene.id)
                }
                if index < scenes.count - 1, let transition = scene.transition {
                    // Örtüşme iki komşu sahneden de pay yer; yarıdan fazlası
                    // sahneyi yutar (üçlü örtüşme compositor'da tanımsız).
                    let limit = min(scene.duration, scenes[index + 1].duration) / 2
                    guard transition.duration >= 0, transition.duration <= limit else {
                        throw TemplateValidationError.invalidTransition(sceneID: scene.id)
                    }
                }

                var videoCapableInScene = 0
                for layer in scene.layers {
                    try validateLayer(layer, in: template,
                                      containerDuration: scene.duration,
                                      layerIDs: &layerIDs, slotIndexes: &slotIndexes,
                                      videoCapableCount: &videoCapableInScene)
                }
                guard videoCapableInScene <= maxVideoSlotsPerScene else {
                    throw TemplateValidationError.tooManyVideoSlotsInScene(sceneID: scene.id)
                }
            }

            // Global overlay katmanları tüm montaj süresine göre doğrulanır;
            // video slotu içeremezler (montaj sahnelere aittir).
            var ignored = 0
            for layer in template.layers {
                try validateLayer(layer, in: template,
                                  containerDuration: template.totalDuration,
                                  layerIDs: &layerIDs, slotIndexes: &slotIndexes,
                                  videoCapableCount: &ignored)
            }
        } else {
            guard template.explicitDuration != nil else {
                throw TemplateValidationError.missingDuration
            }
            var videoCapableSlots = 0
            for layer in template.layers {
                try validateLayer(layer, in: template,
                                  containerDuration: template.totalDuration,
                                  layerIDs: &layerIDs, slotIndexes: &slotIndexes,
                                  videoCapableCount: &videoCapableSlots)
            }
            // Sahnesiz şablonlar CoreAnimationTool yolunda render edilir (v1 kısıtı).
            guard videoCapableSlots <= 1 else {
                throw TemplateValidationError.multipleVideoSlots
            }
        }
    }

    private static func validateLayer(_ layer: Layer,
                                      in template: Template,
                                      containerDuration: Double,
                                      layerIDs: inout Set<String>,
                                      slotIndexes: inout Set<Int>,
                                      videoCapableCount: inout Int) throws {
        guard layerIDs.insert(layer.id).inserted else {
            throw TemplateValidationError.duplicateLayerID(layer.id)
        }

        let window = layer.timing.window(templateDuration: containerDuration)
        guard layer.timing.start >= 0, window.start < window.end else {
            throw TemplateValidationError.invalidTiming(layerID: layer.id)
        }

        switch layer.content {
        case .shape(let shape):
            try requireRole(shape.colorRole, in: template, layerID: layer.id)
            if let gradient = shape.gradient {
                try requireRole(gradient.from, in: template, layerID: layer.id)
                try requireRole(gradient.to, in: template, layerID: layer.id)
            }
        case .text(let text):
            try requireRole(text.colorRole, in: template, layerID: layer.id)
            if let highlight = text.highlightColorRole {
                try requireRole(highlight, in: template, layerID: layer.id)
            }
        case .mediaSlot(let slot):
            guard slotIndexes.insert(slot.slotIndex).inserted else {
                throw TemplateValidationError.duplicateSlotIndex(slot.slotIndex)
            }
            if slot.media.allowsVideo {
                videoCapableCount += 1
            }
        case .lottie(let lottie):
            for role in (lottie.colorRemap ?? [:]).values {
                try requireRole(role, in: template, layerID: layer.id)
            }
        }
    }

    private static func requireRole(_ role: String, in template: Template, layerID: String) throws {
        guard template.palette[role] != nil else {
            throw TemplateValidationError.unknownColorRole(layerID: layerID, role: role)
        }
    }
}
