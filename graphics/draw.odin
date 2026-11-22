package draw

import "../skeltal"
import "../graphics/glTF"

import "core:math/linalg"
import "core:math"
import "core:fmt"
import rl "vendor:raylib"


CUBE_SIZE :: 4.0

// Cube holds the data for a single cube in the world.
Cube :: struct {
	pos:   rl.Vector3,
	color: rl.Color,
}


main :: proc() {


	rl.InitWindow(800, 600, "Skeltal Test")
	defer rl.CloseWindow()

	camera: rl.Camera3D

	camera.position = rl.Vector3{0.0, 20.0, 30.0}
	camera.target = rl.Vector3{0.0, 0.0, 0.0}
	camera.up = rl.Vector3{0.0, 1.0, 0.0}
	camera.fovy = 50
	camera.projection = .PERSPECTIVE

	cube: Cube
	cube.pos = rl.Vector3{0.0, 0.0, 0.0}
	cube.color = rl.RED


	
	q: quaternion256 = quaternion(
    w = 0.0,
    x = 0.0,
    y = 0.0,
    z = 1.0,
)
	// shoulder := skeltal.new_bone("Shoulder", rotation = q)
	// elbow := skeltal.new_bone("Elbow", translation = {6.0, 6.0, 0.0}, parent = shoulder)
	// wrist := skeltal.new_bone("Wrist", translation = {5.0, 0.0, 0.0}, parent = elbow)
	// append(&shoulder.children, elbow)
	// append(&elbow.children, wrist)
	// skeleton := skeltal.new_skeleton(shoulder)

     skeleton := glTF.load_from_gltf("graphics/glTF/example_animation/three-roots-animated-external.gltf", context.allocator)
    if skeleton == nil {
        fmt.eprintln("Failed to load skeleton from glTF.")
        return
    }



	skeltal.calculate_skeleton(skeleton)

	rl.SetTargetFPS(60)
	rl.DisableCursor()
	for !rl.WindowShouldClose() {
		rl.UpdateCamera(&camera, .FREE)

		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		rl.BeginMode3D(camera)
		{
			
			rl.DrawGrid(20, 2.0)
			// X and Z lie on the ground; Y points upward.
			rl.DrawLine3D({-20.0, 0.01, 0.0}, {20.0, 0.01, 0.0}, rl.RED)
			rl.DrawLine3D({0.0, -20.0, 0.0}, {0.0, 20.0, 0.0}, rl.GREEN)
			rl.DrawLine3D({0.0, 0.01, -20.0}, {0.0, 0.01, 20.0}, rl.BLUE)

			//rl.DrawCube(cube.pos, CUBE_SIZE, CUBE_SIZE, CUBE_SIZE, cube.color)
			draw_skeleton(skeleton)
		}

		rl.EndMode3D()
		rl.DrawFPS(10, 70)

		rl.EndDrawing()
	}
}

draw_skeleton :: proc(skeleton: ^skeltal.Skeleton) {
	draw_bone(skeleton.root)
	for b in skeleton.other_bones {
		draw_bone(b)
	}
}

draw_bone :: proc(bone: ^skeltal.Bone) {
	// Draw the bone as a line from the parent to the child
	rl.DrawCube(rl.Vector3 {
		f32(bone.global_transform[0, 3]),
		f32(bone.global_transform[1, 3]),
		f32(bone.global_transform[2, 3]),
	},
		CUBE_SIZE/4, CUBE_SIZE/4, CUBE_SIZE/4, rl.BLUE)
	if bone.parent != nil {
		parent_pos := rl.Vector3 {
			f32(bone.parent.global_transform[0, 3]),
			f32(bone.parent.global_transform[1, 3]),
			f32(bone.parent.global_transform[2, 3]),
		}
		child_pos := rl.Vector3 {
			f32(bone.global_transform[0, 3]),
			f32(bone.global_transform[1, 3]),
			f32(bone.global_transform[2, 3]),
		}
		rl.DrawLine3D(parent_pos, child_pos, rl.YELLOW)
	}

	for b in bone.children {
		draw_bone(b)
	}
}
