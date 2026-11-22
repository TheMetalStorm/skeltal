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
	accessors: [dynamic]^Accessor,
	buffers: [dynamic]^Buffer,
	bufferView: [dynamic]^BufferView,
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

Accessor :: struct {
	buffer_view: int,
	byte_offset: int,
	component_type: int,
	count: int,
	type_: string,
	min: [dynamic]f64,
	max: [dynamic]f64,
	normalized: bool
}
BufferView :: struct {
	// mandatory
	buffer:	int,	
	byteLength:	int,	
	
	// optional
	// TODO: implement optional
	// byteOffset:	int,	
	// byteStride:	int,	
	// target:	int,	
	// name:	string,
	// extensions:	Object,
	// extras:	Any,
}

Buffer :: struct {
	// required
	byteLength: int,

	// optional
	// TODO: implement optional
	uri:	string,
	// name:	string,
	// extensions:	JSON.Object,
	// extras:	Any,
}

load_from_gltf :: proc(path: string, alloc := context.allocator) -> ^skeltal.Skeleton {
	// Load in your json file!
	fmt.printfln("Loading glTF: %s", path)
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
    if animations == nil {
        fmt.eprintln("Failed to load animations from JSON.")
        return nil
    }
    
    // Turn animation data to keyframes, probably???
	print_animations(animations[:])

	// for now only return skeleton, but we can add more functionality later
	return skeleton

}

print_animations :: proc(animations: []^Animation) {
	fmt.printfln("Animations (%d)", len(animations))
	for animation, index in animations {
		fmt.printfln("\n  Animation [%d]: %q", index, animation.name)

		fmt.printfln("    Samplers (%d)", len(animation.samplers))
		for sampler, i in animation.samplers {
			fmt.printfln("      [%d] input accessor=%d, output accessor=%d, interpolation=%q",
				i, sampler.input, sampler.output, sampler.interpolation)
		}

		fmt.printfln("    Channels (%d)", len(animation.channels))
		for channel, i in animation.channels {
			fmt.printfln("      [%d] sampler=%d, target node=%d, target path=%q",
				i, channel.sampler, channel.target_node, channel.target_path)
		}

		fmt.printfln("    Accessors (%d)", len(animation.accessors))
		for accessor, i in animation.accessors {
			fmt.printfln("      [%d] %v", i, accessor^)
		}

		fmt.printfln("    Buffers (%d)", len(animation.buffers))
		for buffer, i in animation.buffers {
			fmt.printfln("      [%d] %v", i, buffer^)

		}

		fmt.printfln("    Buffer views (%d)", len(animation.bufferView))
		for view, i in animation.bufferView {
			fmt.printfln("      [%d] buffer=%d, byte length=%d", i, view.buffer, view.byteLength)
		}
	}
}

load_animation_from_json :: proc(
	json_data: json.Value,
	skeleton: ^skeltal.Skeleton,
	alloc := context.allocator,
) -> [dynamic]^Animation {

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

		accessors_data := json_data.(json.Object)["accessors"]
		if accessors_data == nil {
			fmt.println("INFO: JSON property 'accessors' not found in the glTF file.")
		}

		accessors_array := accessors_data.(json.Array)
		if len(accessors_array) == 0 {
			fmt.println("INFO: 0 accessors found in the glTF file.")
		}

		ret_accessors_array := [dynamic]^Accessor{}
		for accessor in accessors_array {
			accessor_instance := new(Accessor, alloc)
			accessor_data := accessor.(json.Object)

			// ComponentType is mandatory
			component_type := accessor_data["componentType"]
			if component_type == nil {
				fmt.println("INFO: Accessor is missing componentType. It is mandatory.")
				return nil
			}
			accessor_instance.component_type = int(component_type.(json.Float))


			// count is mandatory
			count := accessor_data["count"]
			if count == nil {
				fmt.println("INFO: Accessor is missing count. It is mandatory.")
				return nil
			}
			c := int(count.(json.Float))
			if c < 1 {
				fmt.println("INFO: Count has to be bigger than one")
				return nil
			}
			accessor_instance.count = c


			// type is mandatory
			type_ := accessor_data["type"]
			if type_ == nil {
				fmt.println("INFO: Accessor is missing type. It is mandatory.")
				return nil
			}
			accessor_instance.type_ = type_.(json.String)


			//Min
			min := accessor_data["min"]
			if min != nil {
				min_array := min.(json.Array)
				for v in min_array {
					append(&accessor_instance.min, v.(json.Float))
				}
			}

			//Max
			max := accessor_data["max"]
			if max != nil {
				max_array := max.(json.Array)
				for v in max_array {
					append(&accessor_instance.max, v.(json.Float))
				}
			}

			//Normalized: default false
			normalized := accessor_data["normalized"]
			if normalized == nil {
				fmt.println(
					"INFO: Accessor is missing normalized value. Setting default value to false.",
				)
				accessor_instance.normalized = false
			} else {
				normalized_data := normalized.(json.Boolean)
				accessor_instance.normalized = normalized_data
			}


			// buffer view
			buffer_view := accessor_data["bufferView"]
			if buffer_view == nil {
				fmt.println(
					"INFO: Accessor is missing bufferView value. Data will be initialized with ZEROES",
				)
				// TODO: implement this!!
			} else {
				accessor_instance.buffer_view = int(buffer_view.(json.Float))

				// byte offset must not be present without bufferview: default 0
				byte_offset := accessor_data["byteOffset"]
				if byte_offset == nil {
					fmt.println(
						"INFO: Accessor is missing byteOffset value. Setting default value to 0.",
					)
					accessor_instance.byte_offset = 0
				} else {
					accessor_instance.byte_offset = int(byte_offset.(json.Float))
				}

			}

			log_unsupported_property(accessor_data, "sparse")
			log_unsupported_property(accessor_data, "extensions")
			log_unsupported_property(accessor_data, "extras")
			append(&ret_accessors_array, accessor_instance)
		}

		ret_buffers_array := [dynamic]^Buffer{}

		buffers_data := json_data.(json.Object)["buffers"]
		if buffers_data == nil {
			fmt.println("INFO: JSON property 'buffers' not found in the glTF file.")

		}

		buffers_array := buffers_data.(json.Array)

		for b in buffers_array {
			buffer_ptr := new(Buffer, alloc)
			buffer_object := b.(json.Object)
			byteLength := buffer_object["byteLength"]
			if (byteLength == nil) {
				fmt.println("INFO: JSON property 'byteLength' not found in the glTF file.")
			}
			buffer_ptr.byteLength = int(byteLength.(json.Float))

            uri := buffer_object["uri"]
			if (uri == nil) {
				fmt.println("INFO: JSON property 'uri' not found in the glTF file.")
			}
			buffer_ptr.uri = uri.(json.String)

			log_unsupported_property(buffer_object, "name")
			log_unsupported_property(buffer_object, "extensions")
			log_unsupported_property(buffer_object, "extras")

			append(&ret_buffers_array, buffer_ptr)
		}


		ret_buffer_views_array := [dynamic]^BufferView{}
		buffer_views_array, _ := json_data.(json.Object)["bufferViews"].(json.Array)
		for view in buffer_views_array {
			view_object := view.(json.Object)
			buffer, has_buffer := view_object["buffer"].(json.Float)
			if !has_buffer {
				fmt.println("INFO: BufferView requires the JSON property 'buffer'.")
				return nil
			}
			byteLength, has_byte_length := view_object["byteLength"].(json.Float)
			if !has_byte_length {
				fmt.println("INFO: BufferView requires the JSON property 'byteLength'.")
				return nil
			}

			view_ptr := new(BufferView, alloc)
			view_ptr.buffer = int(buffer)
			view_ptr.byteLength = int(byteLength)

			log_unsupported_property(view_object, "byteOffset")
			log_unsupported_property(view_object, "byteStride")
			log_unsupported_property(view_object, "target")
			log_unsupported_property(view_object, "name")
			log_unsupported_property(view_object, "extensions")
			log_unsupported_property(view_object, "extras")

			append(&ret_buffer_views_array, view_ptr)
		}

		animation_instance.samplers = ret_sampler_array
		animation_instance.channels = ret_channel_array
		animation_instance.accessors = ret_accessors_array
		animation_instance.buffers = ret_buffers_array
		animation_instance.bufferView = ret_buffer_views_array
		append(&res_animations, animation_instance)
	}

	return res_animations

}

log_unsupported_property :: proc(object: json.Object, property: string) {
	if _, present := object[property]; present {
		fmt.printfln("INFO: JSON property '%s' is currently not supported. Skipping.", property)
	}
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
		skeltal.set_translation(
			cur_bone,
			linalg.Vector3f64 {
				translation_array[0].(json.Float),
				translation_array[1].(json.Float),
				translation_array[2].(json.Float),
			},
		)
	}

	rotation := bone_data_obj["rotation"]
	if rotation != nil {
		rotation_array := rotation.(json.Array)
		if len(rotation_array) != 4 {
			fmt.eprintln("Node rotation is not a 4-element array.")
			return
		}
		// Convert quaternion to rotation matrix

		q: linalg.Quaternionf64 = linalg.QUATERNIONF64_IDENTITY
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
		skeltal.set_scale(
			cur_bone,
			linalg.Vector3f64 {
				scale_array[0].(json.Float),
				scale_array[1].(json.Float),
				scale_array[2].(json.Float),
			},
		)
	}


	if skeleton.root == nil {
		skeleton.root = cur_bone
	}


	if parent != nil {
		append(&parent.children, cur_bone)
		cur_bone.parent = parent
	} else if (parent == nil && skeleton.root != nil) {
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
