package glTF

import "../../skeltal"
import "core:encoding/json"
import "core:fmt"
import "core:math/linalg"
import "core:os"

Animation :: struct {
    name: string,
    samplers: [dynamic]^Sampler,
    channels: [dynamic]^Channel,
}

Sampler :: struct {
    input: int,
    interpolation: string,
    output: int,
}

Channel :: struct {
    sampler: int,
    target_node: int,
    target_path: string,
}


load_from_gltf :: proc(path: string, alloc := context.allocator) -> ^skeltal.Skeleton {
	// Load in your json file!
	fmt.print(path)
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		fmt.eprintfln("Failed to load the file: %v", read_err)
		return nil
	}
	defer delete(data) // Free the memory at the end

	// Parse the json file.
	json_data, err := json.parse(data)
	if err != .None {
		fmt.eprintln("Failed to parse the json file.")
		fmt.eprintln("Error:", err)
		return nil
	}

	skeleton := load_skeleton_from_json(json_data, alloc)
    if skeleton == nil {
        fmt.eprintln("Failed to load skeleton from JSON.")
        return nil
    }

    animations := load_animation_from_json(json_data, skeleton, alloc)
	
    // print all animations data
    for animation in animations {
        fmt.println("Animation Name:", animation.name)
        // print complete sampler and channel data
        for sampler in animation.samplers {
            fmt.println("Sampler Input:", sampler.input)
            fmt.println("Sampler Interpolation:", sampler.interpolation)
            fmt.println("Sampler Output:", sampler.output)
        }
        for channel in animation.channels {
            fmt.println("Channel Sampler:", channel.sampler)
            fmt.println("Channel Target Node:", channel.target_node)
            fmt.println("Channel Target Path:", channel.target_path)
        }

    }

    // for now only return skeleton, but we can add more functionality later
	return skeleton

}

load_animation_from_json :: proc(json_data: json.Value, skeleton: ^skeltal.Skeleton, alloc := context.allocator) -> [dynamic]^Animation {

    res_animations := [dynamic]^Animation{}

    animations := json_data.(json.Object)["animations"]
	if animations == nil {
		fmt.eprintln("No animations found in the glTF file.")
		return nil
	}

	animation_data_array := animations.(json.Array)
	if len(animation_data_array) == 0 {
		fmt.eprintln("No animations found in the glTF file.")
		return nil
	}
    

    for animation_data in animation_data_array {
        animation_data_obj := animation_data.(json.Object)
        animation_instance := new(Animation, alloc)

        name := animation_data_obj["name"]
        if name == nil {
            fmt.eprintln("Animation has no name.")
            return nil
        }

        name_string := name.(string)
        animation_instance.name = name_string

        ret_sampler_array := [dynamic]^Sampler{}
        samplers := animation_data_obj["samplers"]
        if samplers == nil {
            fmt.println("INFO: JSON property 'samplers' not found in the glTF file.") 
        }

        samplers_array := samplers.(json.Array)
        if len(samplers_array) == 0 {
            fmt.println("INFO: 0 samplers found in the glTF file.")
        }

        for sampler in samplers_array {
            sampler := sampler.(json.Object)
            input := sampler["input"]
            interpolation := sampler["interpolation"]
            output := sampler["output"] 

            sampler_instance := new(Sampler, alloc)
            sampler_instance.input = int(input.(json.Float))
            sampler_instance.interpolation = interpolation.(json.String)
            sampler_instance.output = int(output.(json.Float))
            append(&ret_sampler_array, sampler_instance)
        }


        ret_channel_array := [dynamic]^Channel{}
        channels_data := animation_data_obj["channels"]
        if channels_data == nil {
            fmt.println("INFO: JSON property 'channels' not found in the glTF file.") 
            return nil
        }

        channels_array := channels_data.(json.Array)
        if len(channels_array) == 0 {
            fmt.println("INFO: 0 channels found in the glTF file.")
            return nil
        }

        for channel in channels_array {
            channel := channel.(json.Object)
            sampler := channel["sampler"]
            target := channel["target"].(json.Object)

            if sampler == nil || target == nil {
                fmt.println("INFO: Channel is missing sampler or target.")
                return nil
            }


            target_node := target["node"]
            target_path := target["path"]

            channel_instance := new(Channel, alloc)
            channel_instance.sampler = int(sampler.(json.Float))
            channel_instance.target_node = int(target_node.(json.Float))
            channel_instance.target_path = target_path.(json.String)

            append(&ret_channel_array, channel_instance)
        }

        animation_instance.samplers = ret_sampler_array
        animation_instance.channels = ret_channel_array
        append(&res_animations, animation_instance)
    }

    return res_animations
    
}

load_skeleton_from_json :: proc(
	json_data: json.Value,
	alloc := context.allocator,
) -> ^skeltal.Skeleton {
	// Implement the logic to load the skeleton from the JSON data
	// This is a placeholder implementation and should be replaced with actual logic
	skeleton := skeltal.new_skeleton(nil, alloc = alloc)
	nodes := json_data.(json.Object)["nodes"]
	if nodes == nil {
		fmt.eprintln("No nodes found in the glTF file.")
		return nil
	}

	nodes_array := nodes.(json.Array)
	if len(nodes_array) == 0 {
		fmt.eprintln("No nodes found in the glTF file.")
		return nil
	}

	checked_nodes := make([]bool, len(nodes_array))
	defer delete(checked_nodes)
	// go through all nodes
	// NOTE: Should check for cycles but lazy
	for i := 0; i < len(nodes_array); i += 1 {


		parse_bone_from_json(nodes_array, i, skeleton, checked_nodes, nil, alloc)


	}


	return skeleton
}

parse_bone_from_json :: proc(
	nodes_array: json.Array,
	index: int,
	skeleton: ^skeltal.Skeleton,
	checked_nodes: []bool,
	parent: ^skeltal.Bone = nil,
	alloc := context.allocator,
) {

	if checked_nodes[index] {
		return
	}

	checked_nodes[index] = true

	bone_data := nodes_array[index]
	bone_data_obj := bone_data.(json.Object)
	name := bone_data_obj["name"]
	if name == nil {
		fmt.eprintln("Node has no name.")
		return
	}
	name_string := name.(string)
	cur_bone := skeltal.new_bone(name_string, alloc = alloc)

	translation := bone_data_obj["translation"]
	if translation != nil {
		translation_array := translation.(json.Array)
		if len(translation_array) != 3 {
			fmt.eprintln("Node translation is not a 3-element array.")
			return
		}
		skeltal.set_translation(cur_bone, linalg.Vector3f64 {
			translation_array[0].(json.Float),
			translation_array[1].(json.Float),
			translation_array[2].(json.Float),
		})
	}

	rotation := bone_data_obj["rotation"]
	if rotation != nil {
		rotation_array := rotation.(json.Array)
		if len(rotation_array) != 4 {
			fmt.eprintln("Node rotation is not a 4-element array.")
			return
		}
		// Convert quaternion to rotation matrix

        q :linalg.Quaternionf64 = linalg.QUATERNIONF64_IDENTITY
        q.x = rotation_array[0].(json.Float)
        q.y = rotation_array[1].(json.Float)
        q.z = rotation_array[2].(json.Float)
        q.w = rotation_array[3].(json.Float)
        skeltal.set_rotation(cur_bone, q)

	}

	scale := bone_data_obj["scale"]
	if scale != nil {
		scale_array := scale.(json.Array)
		if len(scale_array) != 3 {
			fmt.eprintln("Node scale is not a 3-element array.")
			return
		}
		skeltal.set_scale(cur_bone, linalg.Vector3f64 {
			scale_array[0].(json.Float),
			scale_array[1].(json.Float),
			scale_array[2].(json.Float),
		})
	}


	if skeleton.root == nil {
		skeleton.root = cur_bone
	}


	if parent != nil {
		append(&parent.children, cur_bone)
        cur_bone.parent = parent
	}
    else if (  parent == nil && skeleton.root != nil) {
        append(&skeleton.other_bones, cur_bone)
    }


	children := bone_data_obj["children"]
	if children == nil {
		return
	} else {
		children_array := children.(json.Array)
		for child in children_array {
			parse_bone_from_json(
				nodes_array,
				int(child.(json.Float)),
				skeleton,
				checked_nodes,
				cur_bone,
				alloc,
			)
		}

	}
}
