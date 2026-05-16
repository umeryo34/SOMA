//
//  MuscleSceneRendering.swift
//  Fiture
//
//  SceneKit: USDZパーツのハイライト色・タップヒットテスト
//

import ModelIO
import SceneKit
import SceneKit.ModelIO
import SwiftUI
import UIKit

enum MuscleVisualState: Equatable {
    /// 灰色：その日に種目なし、または「黄」から翌日にリセット
    case unused
    /// 赤：その日に同一部位へ **3種目以上** の記録がある
    case trainedToday
    /// 黄：その日に **1〜2種目**、または昨日が赤で今日は未記録（赤→黄）
    case fatigued
}

enum MuscleSceneAppearance {

    /// USD が `Object_7` のように潰れたとき、ここに `"Object_10": .chest` のように **ノード名をそのまま** 追加（前面/背面のログを確認）
    /// ヒットはだいたい `Geometry` 子なので、その親 `Object_N` の名前で引く。
    private static let usdObjectAliases: [String: InteractiveBodyModelView.MuscleType] = [:]

    static func uiColor(for state: MuscleVisualState) -> UIColor {
        switch state {
        case .unused:
            return UIColor.systemGray3
        case .trainedToday:
            return UIColor.systemRed
        case .fatigued:
            return UIColor.systemYellow
        }
    }

    /// Blender / USD のノード名（`node.name` と `geometry.name`）から部位を推定
    static func muscleType(fromSceneNode node: SCNNode) -> InteractiveBodyModelView.MuscleType? {
        var current: SCNNode? = node
        while let n = current {
            for raw in names(from: n) {
                if let mapped = usdObjectAliases[raw] ?? usdObjectAliases[raw.lowercased()] {
                    return mapped
                }
                let lowered = raw.lowercased()
                for rule in nodeNameRules {
                    for pattern in rule.patterns where nameMatches(pattern: pattern, loweredName: lowered) {
                        return rule.muscle
                    }
                }
            }
            current = n.parent
        }
        return nil
    }

    private static func names(from node: SCNNode) -> [String] {
        var out: [String] = []
        if let n = node.name, !n.isEmpty { out.append(n) }
        if let g = node.geometry?.name, !g.isEmpty { out.append(g) }
        return out
    }

    /// ユーザーメッシュ名: Abs, Arm, Back, Bicep, Chest, Leg, Shoulder, Thighs, Tricep など
    private static func nameMatches(pattern: String, loweredName: String) -> Bool {
        let p = pattern.lowercased()
        if p == "arm" {
            return loweredName == "arm" || loweredName == "arms"
        }
        if p == "leg" {
            return loweredName == "leg" || loweredName == "legs"
        }
        return loweredName == p || loweredName.contains(p)
    }

    private struct NodeNameRule {
        let muscle: InteractiveBodyModelView.MuscleType
        let patterns: [String]
    }

    /// 先にマッチさせたいほど上。`shoulders` は `biceps` より先、`biceps` は `腕` より先。
    private static let nodeNameRules: [NodeNameRule] = [
        NodeNameRule(muscle: .chest, patterns: ["chest", "pectoral", "pec", "胸"]),
        NodeNameRule(muscle: .abs, patterns: ["abs", "abdomen", "abdominal", "腹"]),
        NodeNameRule(muscle: .triceps, patterns: ["tricep", "triceps"]),
        /// `shoulder` を二頭より先に（メッシュ名 Shoulder / deltoid 等）
        NodeNameRule(muscle: .shoulders, patterns: ["shoulder", "deltoid", "delts"]),
        NodeNameRule(muscle: .biceps, patterns: ["bicep", "biceps", "brachialis"]),
        /// 上腕・前腕まとめて「腕」（`arm` は完全一致のみ、`forearm` は substring で前方一致）
        NodeNameRule(muscle: .arms, patterns: ["forearm", "wrist"]),
        NodeNameRule(muscle: .arms, patterns: ["arm"]),
        NodeNameRule(muscle: .back, patterns: ["back", "lat", "lats", "trap", "rhomboid", "背"]),
        NodeNameRule(muscle: .thighs, patterns: ["thigh", "thighs", "quad", "hamstring"]),
        NodeNameRule(muscle: .lowerLegs, patterns: ["calf", "shin", "feet", "foot"]),
        NodeNameRule(muscle: .lowerLegs, patterns: ["leg"]),
        NodeNameRule(muscle: .glutes, patterns: ["glute", "butt", "hip"])
    ]

    static func applyHighlightStates(
        to root: SCNNode?,
        states: [InteractiveBodyModelView.MuscleType: MuscleVisualState]
    ) {
        guard let root else { return }
        root.enumerateChildNodes { node, _ in
            guard node.geometry != nil else { return }
            guard let muscle = muscleType(fromSceneNode: node) else { return }
            let state = states[muscle] ?? .unused
            paintGeometry(of: node, color: uiColor(for: state))
        }
    }

    private static func paintGeometry(of node: SCNNode, color: UIColor) {
        guard let geo = node.geometry else { return }
        let count = max(geo.materials.count, 1)
        var materials: [SCNMaterial] = []
        for i in 0..<count {
            let src = geo.materials.indices.contains(i) ? geo.materials[i] : SCNMaterial()
            let m = (src.copy() as? SCNMaterial) ?? SCNMaterial()
            m.diffuse.contents = color
            m.lightingModel = .constant
            m.emission.contents = UIColor.black
            materials.append(m)
        }
        geo.materials = materials
    }
}

struct MuscleHitTestSceneView: UIViewRepresentable {

    /// Y 軸回転（ラジアン）。ドラッグで更新。
    @Binding var orbitYaw: Double
    var muscleStates: [InteractiveBodyModelView.MuscleType: MuscleVisualState]
    let onMuscleTapped: (InteractiveBodyModelView.MuscleType) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        context.coordinator.sceneView = view
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.orbitYawBinding = $orbitYaw
        if uiView.scene == nil {
            uiView.scene = buildHumanScene()
            context.coordinator.lastAppliedStates = nil
        }
        guard let scene = uiView.scene,
              let pivot = scene.rootNode.childNode(withName: HumanBodyUSDSceneKeys.orbitContentNodeName, recursively: false)
        else { return }

        pivot.eulerAngles.y = Float(orbitYaw)

        if context.coordinator.lastAppliedStates != muscleStates {
            MuscleSceneAppearance.applyHighlightStates(to: scene.rootNode, states: muscleStates)
            context.coordinator.lastAppliedStates = muscleStates
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: MuscleHitTestSceneView
        weak var sceneView: SCNView?
        var orbitYawBinding: Binding<Double>?
        var lastAppliedStates: [InteractiveBodyModelView.MuscleType: MuscleVisualState]?
        private var panYawStart: Double = 0

        init(_ parent: MuscleHitTestSceneView) {
            self.parent = parent
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            let pt = gesture.location(in: gesture.view)
            performMuscleHitTest(at: pt)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = sceneView else { return }
            switch gesture.state {
            case .began:
                panYawStart = orbitYawBinding?.wrappedValue ?? 0
            case .changed:
                let t = gesture.translation(in: view)
                guard let bind = orbitYawBinding else { return }
                let sensitivity = (Double.pi * 2) / max(Double(view.bounds.width), 320)
                bind.wrappedValue = panYawStart + Double(t.x) * sensitivity
            default:
                break
            }
        }

        private func performMuscleHitTest(at point: CGPoint) {
            guard let view = sceneView else { return }
            var hits = view.hitTest(point, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .ignoreHiddenNodes: false,
                .boundingBoxOnly: false
            ])
            if hits.isEmpty {
                hits = view.hitTest(point, options: [
                    .boundingBoxOnly: true,
                    .searchMode: SCNHitTestSearchMode.closest.rawValue
                ])
            }
            for hit in hits {
                if hit.node.light != nil { continue }
                if hit.node.camera != nil { continue }
                if hit.node.name == "human_camera" { continue }
                if hit.node.name == HumanBodyUSDSceneKeys.orbitContentNodeName { continue }
                if let muscle = MuscleSceneAppearance.muscleType(fromSceneNode: hit.node) {
                    parent.onMuscleTapped(muscle)
                    return
                }
            }
        }
    }
}

// MARK: - トレ用ボディ USD（human.usdz 等）

/// `Bundle` / `SCNScene(named:)` 用。Xcode の Copy Bundle Resources に含める。
enum HumanBodyUSDResource {
    static let bundleBaseName = "human"
    static let namedSceneFilenames = ["human.usdz", "human.usdc", "human.usd"]
    /// ユーザー向け文言用（メイン想定ファイル）
    static var primaryFilename: String { "\(bundleBaseName).usdz" }
}

enum HumanBodyUSDSceneKeys {
    /// メッシュ・ライトを載せ、ドラッグで Y 回転するノード
    static let orbitContentNodeName = "human_orbit_content"
    /// +X からのプロフィール時、USD の正面が画面左寄りに見えることが多いので初期だけ回す。逆なら符号を反転。
    static let defaultOrbitYawRadians: Double = Double.pi / 2
}

#if DEBUG
/// RealityKit の printTree 相当（SceneKit）。`Object_N` なら `usdObjectAliases` に書く。
func printSCNNodeTree(_ node: SCNNode, level: Int = 0) {
    var extra = ""
    if node.geometry != nil {
        extra = " +"
        if let gn = node.geometry?.name, !gn.isEmpty {
            extra += " g:\(gn)"
        }
        if let mn = node.geometry?.materials.first?.name, !mn.isEmpty {
            extra += " mat:\(mn)"
        }
    }
    print(String(repeating: " ", count: level) + (node.name ?? "(nil)") + extra)
    node.childNodes.forEach { printSCNNodeTree($0, level: level + 2) }
}
#endif

/// ルート自身の `geometry` も含めて走査（USD によってはメッシュがルート直下のみのこともある）。
private func nodeTreeContainsRenderableGeometry(_ node: SCNNode) -> Bool {
    if node.geometry != nil { return true }
    return node.childNodes.contains { nodeTreeContainsRenderableGeometry($0) }
}

private func scnSceneHasRenderableGeometry(_ scene: SCNScene) -> Bool {
    nodeTreeContainsRenderableGeometry(scene.rootNode)
}

private func sceneFromMDLIfAny(url: URL) -> SCNScene? {
    let asset = MDLAsset(url: url)
    guard asset.count > 0 else { return nil }
    return SCNScene(mdlAsset: asset)
}

private func sceneFromSceneKitURL(url: URL) -> SCNScene? {
    do {
        return try SCNScene(url: url, options: nil)
    } catch {
        #if DEBUG
        print("human USD: SCNScene(url:) failed \(url.lastPathComponent): \(error)")
        #endif
        return nil
    }
}

/// `usdz` は `SCNScene(url:)` が安定しやすい。`.usdc` / `.usd` は `MDLAsset` を先に試す。
private func loadSceneFromURLPreferringSceneKitForUSDZ(_ url: URL, ext: String) -> SCNScene? {
    let sk = sceneFromSceneKitURL(url: url)
    let mdl = sceneFromMDLIfAny(url: url)
    let ordered: [SCNScene?] = (ext == "usdz") ? [sk, mdl] : [mdl, sk]
    return ordered.compactMap({ $0 }).first(where: scnSceneHasRenderableGeometry)
}

private func loadHumanBaseSceneFromBundle() -> SCNScene? {
    let extensions = ["usdz", "usdc", "usd"]
    for ext in extensions {
        guard let url = Bundle.main.url(forResource: HumanBodyUSDResource.bundleBaseName, withExtension: ext) else { continue }
        #if DEBUG
        print("human USD: trying \(url.lastPathComponent)")
        #endif
        if let scene = loadSceneFromURLPreferringSceneKitForUSDZ(url, ext: ext) {
            return scene
        }
        #if DEBUG
        let sk = sceneFromSceneKitURL(url: url)
        let mdlCount = MDLAsset(url: url).count
        let skChildren = sk?.rootNode.childNodes.count ?? -1
        let skMesh = sk.map { scnSceneHasRenderableGeometry($0) } ?? false
        print("human USD: rejected \(url.lastPathComponent) — SK scene=\(sk != nil) MDL objects=\(mdlCount) rootChildren=\(skChildren) hasMesh=\(skMesh)")
        if let sk, !skMesh, skChildren > 0 {
            print("human USD: シーンは開けていますが SCNGeometry がありません（env_light などのみ）。いまの human.usdz にはポリゴンメッシュが入っていない可能性が高いです。Blender ではオブジェクトを選択し「USD Universal」等でメッシュごと書き出してください。")
        }
        #endif
    }
    for name in HumanBodyUSDResource.namedSceneFilenames {
        if let scene = SCNScene(named: name), scnSceneHasRenderableGeometry(scene) {
            return scene
        }
    }
    #if DEBUG
    let usdc = Bundle.main.paths(forResourcesOfType: "usdc", inDirectory: nil)
    let usdz = Bundle.main.paths(forResourcesOfType: "usdz", inDirectory: nil)
    let bundleHasUSDZ = Bundle.main.url(forResource: HumanBodyUSDResource.bundleBaseName, withExtension: "usdz") != nil
    if bundleHasUSDZ {
        print("human USD: load failed — \(HumanBodyUSDResource.primaryFilename) is in the app bundle but SceneKit/MDL did not yield a usable scene. See \"rejected\" line above; try re-exporting USDZ.")
    } else {
        print("human USD: load failed — add \(HumanBodyUSDResource.primaryFilename) to the app target Copy Bundle Resources. usdc=\(usdc) usdz=\(usdz)")
    }
    #endif
    return nil
}

func buildHumanScene() -> SCNScene? {
    guard let scene = loadHumanBaseSceneFromBundle() else {
        return nil
    }
    let rootNode = scene.rootNode

    let contentNode = SCNNode()
    contentNode.name = HumanBodyUSDSceneKeys.orbitContentNodeName
    for child in rootNode.childNodes {
        contentNode.addChildNode(child)
    }
    rootNode.addChildNode(contentNode)

    let (minBox, maxBox) = worldBoundingBox(of: contentNode)
    let hasValidBounds = minBox.x < maxBox.x && minBox.y < maxBox.y && minBox.z < maxBox.z

    let extentX = maxBox.x - minBox.x
    let extentY = maxBox.y - minBox.y
    let extentZ = maxBox.z - minBox.z
    let largestExtent = max(extentX, max(extentY, extentZ))

    if hasValidBounds {
        let center = SCNVector3(
            (minBox.x + maxBox.x) * 0.5,
            (minBox.y + maxBox.y) * 0.5,
            (minBox.z + maxBox.z) * 0.5
        )
        /// バウンディング中心を原点附近に
        let verticalLift = largestExtent * 0.36
        contentNode.position = SCNVector3(-center.x, -center.y + verticalLift, -center.z)
    } else {
        contentNode.position = SCNVector3(0, 0, 0)
    }
    contentNode.eulerAngles = SCNVector3(0, 0, 0)
    contentNode.scale = SCNVector3(1.08, 1.08, 1.08)

    /// 寄って大きく見せる（クリップしたら係数だけ少し上げる）
    let cameraDistance = hasValidBounds ? max(0.94, largestExtent * 1.12) : 3.2
    /// ピボットよりだいぶ上にカメラ → 画面上でモデルをはっきり上へ（距離・スケールは据え置き）
    let cameraSideYOffset = hasValidBounds ? contentNode.position.y + largestExtent * 0.20 : 0.08

    let cameraNode = SCNNode()
    cameraNode.name = "human_camera"
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.fieldOfView = 61
    cameraNode.camera?.zNear = 0.01
    cameraNode.camera?.zFar = 10_000
    cameraNode.position = SCNVector3(cameraDistance, cameraSideYOffset, 0)
    let lookAt = SCNLookAtConstraint(target: contentNode)
    lookAt.isGimbalLockEnabled = true
    /// 注視をピボットより大きく下へ（足〜下半身側）へずらして全体をフレーム上寄せ
    lookAt.targetOffset = SCNVector3(0, hasValidBounds ? -largestExtent * 0.24 : 0, 0)
    cameraNode.constraints = [lookAt]

    scene.rootNode.addChildNode(cameraNode)

    let lightNode = SCNNode()
    lightNode.light = SCNLight()
    lightNode.light?.type = .omni
    lightNode.position = SCNVector3(0, cameraDistance * 0.4, cameraDistance * 0.7)
    scene.rootNode.addChildNode(lightNode)

    let ambientLightNode = SCNNode()
    ambientLightNode.light = SCNLight()
    ambientLightNode.light?.type = .ambient
    ambientLightNode.light?.intensity = 500
    scene.rootNode.addChildNode(ambientLightNode)

    #if DEBUG
    print("— human USD (orbit pivot) —")
    printSCNNodeTree(scene.rootNode)
    #endif

    return scene
}

private func worldBoundingBox(of root: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
    var minVec = SCNVector3(Float.greatestFiniteMagnitude,
                            Float.greatestFiniteMagnitude,
                            Float.greatestFiniteMagnitude)
    var maxVec = SCNVector3(-Float.greatestFiniteMagnitude,
                            -Float.greatestFiniteMagnitude,
                            -Float.greatestFiniteMagnitude)
    var hasGeometry = false

    root.enumerateChildNodes { node, _ in
        guard node.geometry != nil else { return }
        let (localMin, localMax) = node.boundingBox
        let corners = [
            SCNVector3(localMin.x, localMin.y, localMin.z),
            SCNVector3(localMin.x, localMin.y, localMax.z),
            SCNVector3(localMin.x, localMax.y, localMin.z),
            SCNVector3(localMin.x, localMax.y, localMax.z),
            SCNVector3(localMax.x, localMin.y, localMin.z),
            SCNVector3(localMax.x, localMin.y, localMax.z),
            SCNVector3(localMax.x, localMax.y, localMin.z),
            SCNVector3(localMax.x, localMax.y, localMax.z)
        ]

        for corner in corners {
            let world = node.convertPosition(corner, to: root)
            minVec.x = min(minVec.x, world.x)
            minVec.y = min(minVec.y, world.y)
            minVec.z = min(minVec.z, world.z)
            maxVec.x = max(maxVec.x, world.x)
            maxVec.y = max(maxVec.y, world.y)
            maxVec.z = max(maxVec.z, world.z)
            hasGeometry = true
        }
    }

    if !hasGeometry {
        return (SCNVector3(0, 0, 0), SCNVector3(1, 1, 1))
    }
    return (minVec, maxVec)
}
