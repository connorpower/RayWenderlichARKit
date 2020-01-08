//
//  SCNNodeHelpers.swift
//  Portal
//
//  Created by Connor Power on 03/01/2020.
//  Copyright © 2020 Namrata Bandekar. All rights reserved.
//

import Foundation
import SceneKit

struct Constants {
    static let innerCubeLength: CGFloat = 3.0
    static let doorHeight: CGFloat = 0.8 * innerCubeLength
    static let doorWidth: CGFloat = 0.4 * innerCubeLength
    static let wallThickness: CGFloat = 0.1
    static let lightIntensity: CGFloat = 2
    static let lightOffset: CGFloat = 0.02
}

struct Materials {
    static var floor: SCNMaterial! = {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIImage(named: "Assets.scnassets/floor/textures/Floor_Diffuse.png")
        material.normal.contents = UIImage(named: "Assets.scnassets/floor/textures/Floor_Normal.png")
        material.specular.contents = UIImage(named: "Assets.scnassets/floor/textures/Floor_Specular.png")
        material.roughness.contents = UIImage(named: "Assets.scnassets/floor/textures/Floor_Roughness.png")
        material.selfIllumination.contents = UIImage(named: "Assets.scnassets/floor/textures/Floor_Gloss.png")
        material.name = "floor"
        return material
    }()

    static var wall: SCNMaterial! = {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIImage(named: "Assets.scnassets/wall/textures/Walls_Diffuse.png")
        material.normal.contents = UIImage(named: "Assets.scnassets/wall/textures/Walls_Normal.png")
        material.specular.contents = UIImage(named: "Assets.scnassets/wall/textures/Walls_Specular.png")
        material.roughness.contents = UIImage(named: "Assets.scnassets/wall/textures/Walls_Roughness.png")
        material.selfIllumination.contents = UIImage(named: "Assets.scnassets/wall/textures/Walls_Gloss.png")
        material.name = "wall"
        return material
    }()

    static var ceiling: SCNMaterial! = {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIImage(named: "Assets.scnassets/ceiling/textures/Ceiling_Diffuse.png")
        material.normal.contents = UIImage(named: "Assets.scnassets/ceiling/textures/Ceiling_Normal.png")
        material.specular.contents = UIImage(named: "Assets.scnassets/ceiling/textures/Ceiling_Specular.png")
        material.roughness.contents = UIImage(named: "Assets.scnassets/ceiling/textures/Ceiling_Roughness.png")
        material.selfIllumination.contents = UIImage(named: "Assets.scnassets/ceiling/textures/Ceiling_Gloss.png")
        material.name = "ceiling"
        return material
    }()

    static var transparent: SCNMaterial! = {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.transparency = 0.000001
        material.name = "transparent"
        return material
    }()
}

func repeatTextures(geometry: SCNGeometry, scaleX: Float = 2.0, scaleY: Float = 2.0) {
    geometry.firstMaterial?.diffuse.wrapS = .repeat
    geometry.firstMaterial?.selfIllumination.wrapS = .repeat
    geometry.firstMaterial?.normal.wrapS = .repeat
    geometry.firstMaterial?.specular.wrapS = .repeat
    geometry.firstMaterial?.emission.wrapS = .repeat
    geometry.firstMaterial?.roughness.wrapS = .repeat

    geometry.firstMaterial?.diffuse.wrapT = .repeat
    geometry.firstMaterial?.selfIllumination.wrapT = .repeat
    geometry.firstMaterial?.normal.wrapT = .repeat
    geometry.firstMaterial?.specular.wrapT = .repeat
    geometry.firstMaterial?.emission.wrapT = .repeat
    geometry.firstMaterial?.roughness.wrapT = .repeat

    let scaleTransform = SCNMatrix4MakeScale(scaleX, scaleY, 0)
    geometry.firstMaterial?.diffuse.contentsTransform = scaleTransform
    geometry.firstMaterial?.selfIllumination.contentsTransform = scaleTransform
    geometry.firstMaterial?.normal.contentsTransform = scaleTransform
    geometry.firstMaterial?.specular.contentsTransform = scaleTransform
    geometry.firstMaterial?.emission.contentsTransform = scaleTransform
    geometry.firstMaterial?.roughness.contentsTransform = scaleTransform
}

/**
 Constructs a floor node (complete with visible inner layer and invisible outer layer).

 The node's origin is centered directly underneath the visible floor such that placing the floor
 node on a surface at 0, 0, 0 will result in the floor sitting visibly flat.
 */
func makeFloorNode() -> SCNNode {
    let outerFloor = SCNBox(width: Constants.innerCubeLength,
                                height: Constants.wallThickness,
                                length: Constants.innerCubeLength,
                                chamferRadius: 0.0)
    outerFloor.firstMaterial = Materials.transparent

    let outerFloorNode = SCNNode(geometry: outerFloor)
    outerFloorNode.name = "floor_outer"
    outerFloorNode.renderingOrder = 10
    outerFloorNode.position = SCNVector3(0,
                                         -Constants.wallThickness + Constants.wallThickness * 0.5,
                                         0)

    let floorNode = SCNNode()
    floorNode.name = "floor"
    floorNode.addChildNode(outerFloorNode)

    let innerFloor = SCNBox(width: Constants.innerCubeLength,
                            height: Constants.wallThickness,
                            length: Constants.innerCubeLength,
                            chamferRadius: 0.0)

    innerFloor.firstMaterial = Materials.floor
    repeatTextures(geometry: innerFloor)

    let innerFloorNode = SCNNode(geometry: innerFloor)
    innerFloorNode.name = "floor_inner"
    innerFloorNode.renderingOrder = 100
    innerFloorNode.position = SCNVector3( 0,
                                         +Constants.wallThickness * 0.5,
                                          0)

    floorNode.addChildNode(innerFloorNode)
    return floorNode
}

/**
 Returns an invisible column `innerCubeLength` long in the `x` dimension and `wallThickness` wide
 in the `y` and `z` dimensions.
 */
func makeInvisbleColumn() -> SCNNode {
    let column = SCNBox(width: Constants.innerCubeLength,
                        height: Constants.wallThickness,
                        length: Constants.wallThickness,
                        chamferRadius: 0.0)

    column.firstMaterial = Materials.transparent

    let columnNode = SCNNode(geometry: column)
    columnNode.name = "column"
    columnNode.renderingOrder = 10

    return columnNode
}

/**
Constructs a ceiling node (complete with visible inner layer and invisible outer layer).

The node's origin is centered directly underneath the visible ceiling such that placing the ceiling
node on top of a wall will result in the ceiling sitting visibly flush atop the walls.
*/
func makeCeilingNode() -> SCNNode {
    let outerCeiling = SCNBox(width: Constants.innerCubeLength,
                                height: Constants.wallThickness,
                                length: Constants.innerCubeLength,
                                chamferRadius: 0.0)
    outerCeiling.firstMaterial = Materials.transparent

    let outerCeilingNode = SCNNode(geometry: outerCeiling)
    outerCeilingNode.name = "ceiling_outer"
    outerCeilingNode.renderingOrder = 10
    outerCeilingNode.position = SCNVector3( 0,
                                           +Constants.wallThickness + Constants.wallThickness * 0.5,
                                            0)

    let ceilingNode = SCNNode()
    ceilingNode.name = "ceiling"
    ceilingNode.addChildNode(outerCeilingNode)

    let innerCeiling = SCNBox(width: Constants.innerCubeLength,
                              height: Constants.wallThickness,
                              length: Constants.innerCubeLength,
                              chamferRadius: 0.0)

    innerCeiling.firstMaterial = Materials.ceiling
    repeatTextures(geometry: innerCeiling)

    let innerCeilingNode = SCNNode(geometry: innerCeiling)
    innerCeilingNode.name = "ceiling_inner"
    innerCeilingNode.renderingOrder = 100

    innerCeilingNode.position = SCNVector3( 0,
                                           +Constants.wallThickness * 0.5,
                                            0)

    ceilingNode.addChildNode(innerCeilingNode)
    return ceilingNode
}

/**
 Constructs a wall node (complete with visible inner layer and invisible outer layer).

 The node's origin is centered directly within the visible wall panel. When positioning the
 wall flush against another object, the wall should therefore be shifted +/- half the thickness
 to account for the origin directly in the center of the wall's thickness.
*/
func makeWallNode(length: CGFloat = Constants.innerCubeLength,
                  height: CGFloat = Constants.innerCubeLength,
                  maskLowerSide: Bool = false) -> SCNNode {
    let outerWall = SCNBox(width: Constants.wallThickness,
                           height: height,
                           length: length,
                           chamferRadius: 0.0)
    outerWall.firstMaterial = Materials.transparent

    let outerWallNode = SCNNode(geometry: outerWall)
    outerWallNode.name = "wall_outer"
    let multiplier: CGFloat = maskLowerSide ? -1 : 1
    outerWallNode.position = SCNVector3(+Constants.wallThickness * multiplier,
                                         0,
                                         0)
    outerWallNode.renderingOrder = 10

    let wallNode = SCNNode()
    wallNode.addChildNode(outerWallNode)

    let innerWall = SCNBox(width: Constants.wallThickness,
                           height: height,
                           length: length,
                           chamferRadius: 0.0)

    innerWall.firstMaterial = Materials.wall

    let innerWallNode = SCNNode(geometry: innerWall)
    innerWallNode.name = "wall_inner"
    innerWallNode.renderingOrder = 100
    wallNode.addChildNode(innerWallNode)

    return wallNode
}

/**
Constructs a simple transparent yellow rectangle to indicate a selectable plane.
*/
func createPlaneNode(center: vector_float3, extent: vector_float3) -> SCNNode {
    let plane = SCNPlane(width: CGFloat(extent.x),
                         height: CGFloat(extent.z))

    let planeMaterial = SCNMaterial()
    planeMaterial.diffuse.contents = UIColor.yellow.withAlphaComponent(0.4)
    plane.materials = [planeMaterial]

    let planeNode = SCNNode(geometry: plane)
    planeNode.name = "plane_node"
    planeNode.renderingOrder = 200
    planeNode.position = SCNVector3Make(center.x, 0, center.z)
    planeNode.transform = SCNMatrix4MakeRotation(-(.pi / 2.0), 1.0, 0.0, 0.0)

    return planeNode
}

/**
Updates the extent and position of a plane previously created with `createPlaneNode(center:extent:)`.
*/
func updatePlaneNode(plane: SCNNode, center: vector_float3, extent: vector_float3) {
    guard let geometry = plane.geometry as? SCNPlane else { return }

    geometry.width = CGFloat(extent.x)
    geometry.height = CGFloat(extent.z)

    plane.position = SCNVector3Make(center.x, 0.0, center.z)
}
