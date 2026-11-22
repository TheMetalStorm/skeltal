package skeltal

import "core:math/linalg"

Bone :: struct {
	name:             string,
	children:         [dynamic]^Bone,
	parent:           ^Bone,
	//position: linalg.Vector3f64,
	local_transform:  linalg.Matrix4x4f64,
	scale:            linalg.Vector3f64,
    translation:      linalg.Vector3f64,
    rotation:         linalg.Quaternionf64,
    
    global_transform: linalg.Matrix4x4f64,
    dirty: bool,
}

Skeleton :: struct {
	root: ^Bone ,
	other_bones: [dynamic]^Bone,
	keyframes: [dynamic]^Keyframe,
}

Keyframe :: struct {
	
}



new_skeleton :: proc(root: ^Bone, alloc := context.allocator) -> ^Skeleton {
    skeleton: ^Skeleton = new(Skeleton, alloc)
    skeleton.root = root
    return skeleton
}

new_bone :: proc(
	name: string,
	scale: linalg.Vector3f64 = {1.0, 1.0, 1.0},
    translation: linalg.Vector3f64 = {0.0, 0.0, 0.0},
	rotation: linalg.Quaternionf64 = linalg.QUATERNIONF64_IDENTITY,
	parent: ^Bone = nil,
    alloc:= context.allocator
) -> ^Bone {

	bone: ^Bone = new(Bone, alloc)

	bone.name = name
	bone.parent = parent

	bone.scale = scale
	bone.translation = translation
	bone.rotation = rotation

    bone.local_transform = linalg.matrix4_from_trs_f64(
		bone.translation,
		bone.rotation,
		bone.scale,
	)
    bone.dirty = false

	return bone

}

set_scale :: proc(bone: ^Bone, scale: linalg.Vector3f64) {
    bone.scale = scale
    bone.dirty = true
}

set_translation :: proc(bone: ^Bone, translation: linalg.Vector3f64) {
    bone.translation = translation
    bone.dirty = true
}

set_rotation :: proc(bone: ^Bone, rotation: linalg.Quaternionf64) {
    bone.rotation = rotation
    bone.dirty = true
}

calculate_bone_global_transform :: proc(bone: ^Bone) {

    if bone.dirty {
        bone.local_transform = linalg.matrix4_from_trs_f64(
            bone.translation,
            bone.rotation,
            bone.scale,
        )
        bone.dirty = false
    }

	if bone.parent == nil {
		bone.global_transform = bone.local_transform
	} else {
		bone.global_transform = linalg.matrix_mul(
			bone.parent.global_transform,
			bone.local_transform,
		)
	}
	for b in bone.children {
		calculate_bone_global_transform(b)
	}


}




//  globalTransform(bone)=globalTransform(parent)⋅localTransform(bone)

//If a bone doesn't have a parent, its globalTransform coincides with the localTransform. We'll talk about where these localTransforms come from later in the article.
calculate_skeleton :: proc(skeleton: ^Skeleton) {
	calculate_bone_global_transform(skeleton.root)
	for b in skeleton.other_bones {
		calculate_bone_global_transform(b)
	}
}
