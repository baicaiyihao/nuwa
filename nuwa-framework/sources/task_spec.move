module nuwa_framework::task_spec {
    use std::vector;                          // 导入标准库中的向量模块
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::option::{Self, Option};         // 导入标准库中的选项模块，并引入 Option 类型
    use moveos_std::json;                     // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::decimal_value::{Self, DecimalValue};  // 导入 MoveOS 标准库中的十进制值模块，并引入 DecimalValue 类型
    use nuwa_framework::string_utils::{Self, build_json_section};  // 导入 nuwa_framework 中的字符串工具模块，并引入 build_json_section 函数

    const MAX_TASK_SPECIFICATIONS: u64 = 5;   // 定义常量：任务规格的最大数量
    const TASK_NAME_PREFIX: vector<u8> = b"task::";  // 定义常量：任务名称的前缀

    const ErrorInvalidTaskSpecifications: u64 = 1;  // 定义错误码：无效的任务规格

    #[data_struct]
    struct TaskSpecifications has copy, drop, store {  // 定义任务规格集合结构体，具有 copy、drop、store 能力
        task_specs: vector<TaskSpecification>,  // 任务规格向量，包含多个任务规格
    }

    #[data_struct]
    struct TaskSpecification has copy, drop, store {  // 定义任务规格结构体，具有 copy、drop、store 能力
        name: String,                         // 任务名称
        description: String,                  // 任务描述
        arguments: vector<TaskArgument>,      // 任务参数向量
        resolver: address,                    // 任务解析者地址
        on_chain: bool,                       // 是否为链上任务
        price: DecimalValue,                  // 任务价格，类型为十进制值
    }

    #[data_struct]
    struct TaskArgument has copy, drop, store {  // 定义任务参数结构体，具有 copy、drop、store 能力
        name: String,                         // 参数名称
        type_desc: String,                    // 参数类型描述
        description: String,                  // 参数描述
        required: bool,                       // 是否为必填参数
    }

    public fun empty_task_specifications(): TaskSpecifications {  // 定义公开函数：创建空的任務規格集合
        TaskSpecifications {                  // 返回一个空的 TaskSpecifications 实例
            task_specs: vector[],             // 任务规格向量初始化为空
        }
    }

    public fun new_task_specifications(task_specs: vector<TaskSpecification>): TaskSpecifications {  // 定义公开函数：创建新的任务规格集合
        TaskSpecifications {                  // 返回一个新的 TaskSpecifications 实例
            task_specs,                       // 使用传入的任务规格向量
        }
    }

    public fun new_task_spec(name: String, description: String, arguments: vector<TaskArgument>, resolver: address, on_chain: bool, price: DecimalValue): TaskSpecification {  // 定义公开函数：创建新的任务规格
        TaskSpecification {                   // 返回一个新的 TaskSpecification 实例
            name,                             // 任务名称
            description,                      // 任务描述
            arguments,                        // 任务参数
            resolver,                         // 任务解析者地址
            on_chain,                         // 是否链上任务
            price,                            // 任务价格
        }
    }

    public fun new_task_argument(name: String, type_desc: String, description: String, required: bool): TaskArgument {  // 定义公开函数：创建新的任务参数
        TaskArgument {                        // 返回一个新的 TaskArgument 实例
            name,                             // 参数名称
            type_desc,                        // 参数类型描述
            description,                      // 参数描述
            required,                         // 是否必填
        }
    }

    public fun task_specs_from_json(json_str: String): TaskSpecifications {  // 定义公开函数：从 JSON 字符串解析任务规格集合
        let json_str_bytes = string::into_bytes(json_str);  // 将 JSON 字符串转换为字节向量
        let task_specs = json::from_json<TaskSpecifications>(json_str_bytes);  // 从字节向量解析出 TaskSpecifications
        task_specs                            // 返回解析出的任务规格集合
    }

    public fun task_specs_to_json(task_specs: &TaskSpecifications): String {  // 定义公开函数：将任务规格集合转换为 JSON 字符串
        let json_str_bytes = json::to_json(task_specs);  // 将任务规格集合转换为 JSON 字节向量
        string::utf8(json_str_bytes)          // 将字节向量转换为 UTF-8 字符串并返回
    }

    public fun validate_task_specifications(task_specs: &TaskSpecifications) {  // 定义公开函数：验证任务规格集合的有效性
        assert!(is_validate_task_specifications(task_specs), ErrorInvalidTaskSpecifications);  // 断言：如果验证失败，抛出无效任务规格错误
    }

    public fun is_validate_task_specifications(task_specs: &TaskSpecifications): bool {  // 定义公开函数：检查任务规格集合是否有效
        let length = vector::length(&task_specs.task_specs);  // 获取任务规格向量的长度
        if (length > MAX_TASK_SPECIFICATIONS) {  // 如果长度超过最大限制
            return false                      // 返回 false
        };
        let idx = 0;                          // 初始化索引
        while (idx < length) {                // 遍历任务规格向量
            let task_spec = vector::borrow(&task_specs.task_specs, idx);  // 借用当前任务规格
            if (!is_validate_task_name(&task_spec.name)) {  // 检查任务名称是否有效
                return false                  // 如果无效，返回 false
            };
            let arguments = task_spec.arguments;  // 获取当前任务的参数向量
            let arguments_length = vector::length(&arguments);  // 获取参数向量的长度
            let arguments_idx = 0;            // 初始化参数索引
            while (arguments_idx < arguments_length) {  // 遍历参数向量
                let argument = vector::borrow(&arguments, arguments_idx);  // 借用当前参数
                if (!is_validate_task_argument_type_desc(&argument.type_desc)) {  // 检查参数类型描述是否有效
                    return false              // 如果无效，返回 false
                };
                arguments_idx = arguments_idx + 1;  // 参数索引递增
            };
            idx = idx + 1;                    // 任务规格索引递增
        };
        true                                  // 所有检查通过，返回 true
    }

    const TASK_ARGUMENT_TYPE_DESCS: vector<vector<u8>> = vector[  // 定义常量：支持的任务参数类型描述列表
        b"string",                        // 字符串类型
        b"number",                        // 数字类型
        b"boolean",                       // 布尔类型
    ];

    public fun is_validate_task_argument_type_desc(type_desc: &String): bool {  // 定义公开函数：检查任务参数类型描述是否有效
        let length = string::length(type_desc);  // 获取类型描述的长度
        if (length == 0) {                    // 如果长度为 0（空字符串）
            return false                      // 返回 false
        };
        let idx = 0;                          // 初始化索引
        let length = vector::length(&TASK_ARGUMENT_TYPE_DESCS);  // 获取支持类型描述列表的长度
        while (idx < length) {                // 遍历支持的类型描述列表
            let allowed_type_desc = vector::borrow(&TASK_ARGUMENT_TYPE_DESCS, idx);  // 借用当前支持的类型描述
            if (string::bytes(type_desc) == allowed_type_desc) {  // 如果类型描述匹配
                return true                   // 返回 true
            };
            idx = idx + 1;                    // 索引递增
        };
        false                                 // 未找到匹配，返回 false
    }

    /// validate task specification name        // 注释：验证任务规格名称
    /// The task specification name must be a valid function name  // 注释：任务规格名称必须是有效的函数名
    public fun is_validate_task_name(name: &String): bool {  // 定义公开函数：检查任务名称是否有效
        let length = string::length(name);    // 获取名称的长度
        // Name cannot be empty               // 注释：名称不能为空
        if (length == 0) {                    // 如果名称长度为 0
            return false                      // 返回 false
        };
        // Name must start with the prefix    // 注释：名称必须以指定前缀开头
        if (!string_utils::starts_with(name, &TASK_NAME_PREFIX)) {  // 检查名称是否以 "task::" 开头
            return false                      // 如果不是，返回 false
        };
        let name_without_prefix = string::sub_string(name, 6, length);  // 去除前缀 "task::"，获取剩余部分
        let name_bytes = string::bytes(&name_without_prefix);  // 将剩余部分转换为字节向量
        let length = vector::length(name_bytes);  // 获取字节向量的长度
        // First character must be a letter or underscore  // 注释：第一个字符必须是字母或下划线
        let first_char = *vector::borrow(name_bytes, 0);  // 获取第一个字符
        if (!is_letter(first_char) && first_char != 95) {  // 检查是否为字母或下划线（95 是 '_' 的 ASCII 码）
            return false                      // 如果不是，返回 false
        };
        // Rest characters must be letters, numbers or underscore  // 注释：其余字符必须是字母、数字或下划线
        let i = 1;                            // 初始化索引，从第二个字符开始
        while (i < length) {                  // 遍历剩余字符
            let char = *vector::borrow(name_bytes, i);  // 获取当前字符
            if (!is_letter(char) && !is_number(char) && char != 95) {  // 检查是否为字母、数字或下划线
                return false                  // 如果不是，返回 false
            };
            i = i + 1;                        // 索引递增
        };
        true                                  // 所有检查通过，返回 true
    }

    fun is_letter(char: u8): bool {           // 定义函数：检查字符是否为字母
        // Check if char is a-z or A-Z      // 注释：检查字符是否为 a-z 或 A-Z
        (char >= 97 && char <= 122) || (char >= 65 && char <= 90)  // 返回 true 如果是小写字母 (97-122) 或大写字母 (65-90)
    }

    fun is_number(char: u8): bool {           // 定义函数：检查字符是否为数字
        // Check if char is 0-9            // 注释：检查字符是否为 0-9
        char >= 48 && char <= 57          // 返回 true 如果是数字 (48-57)
    }

    public fun get_task_spec_by_name(task_specs: &TaskSpecifications, name: String): Option<TaskSpecification> {  // 定义公开函数：根据名称获取任务规格
        let length = vector::length(&task_specs.task_specs);  // 获取任务规格向量的长度
        let idx = 0;                          // 初始化索引
        while (idx < length) {                // 遍历任务规格向量
            let task_spec = vector::borrow(&task_specs.task_specs, idx);  // 借用当前任务规格
            if (task_spec.name == name) {     // 如果名称匹配
                return option::some(*task_spec)  // 返回匹配的任务规格（复制一份）
            };
            idx = idx + 1;                    // 索引递增
        };
        option::none()                        // 未找到匹配，返回空
    }

    public fun get_task_name(task_spec: &TaskSpecification): &String {  // 定义公开函数：获取任务规格的名称
        &task_spec.name                       // 返回任务名称的引用
    }

    public fun get_task_description(task_spec: &TaskSpecification): &String {  // 定义公开函数：获取任务规格的描述
        &task_spec.description                // 返回任务描述的引用
    }

    public fun get_task_arguments(task_spec: &TaskSpecification): &vector<TaskArgument> {  // 定义公开函数：获取任务规格的参数向量
        &task_spec.arguments                  // 返回任务参数向量的引用
    }
    
    public fun get_task_resolver(task_spec: &TaskSpecification): address {  // 定义公开函数：获取任务规格的解析者地址
        task_spec.resolver                    // 返回解析者地址
    }

    public fun is_task_on_chain(task_spec: &TaskSpecification): bool {  // 定义公开函数：检查任务是否为链上任务
        task_spec.on_chain                    // 返回是否链上任务的布尔值
    }

    public fun get_task_argument_name(task_argument: &TaskArgument): &String {  // 定义公开函数：获取任务参数的名称
        &task_argument.name                   // 返回参数名称的引用
    }

    public fun get_task_argument_type_desc(task_argument: &TaskArgument): &String {  // 定义公开函数：获取任务参数的类型描述
        &task_argument.type_desc              // 返回参数类型描述的引用
    }

    public fun get_task_argument_description(task_argument: &TaskArgument): &String {  // 定义公开函数：获取任务参数的描述
        &task_argument.description            // 返回参数描述的引用
    }

    public fun is_task_argument_required(task_argument: &TaskArgument): bool {  // 定义公开函数：检查任务参数是否为必填
        task_argument.required                // 返回是否必填的布尔值
    }

    public fun get_task_price(task_spec: &TaskSpecification): DecimalValue {  // 定义公开函数：获取任务规格的价格
        task_spec.price                       // 返回任务价格
    }

    public fun to_prompt(task_specs: &TaskSpecifications): String {  // 定义公开函数：将任务规格集合转换为提示字符串
        if (vector::length(&task_specs.task_specs) == 0) {  // 如果任务规格向量为空
            return string::utf8(b"")          // 返回空字符串
        };
        let prompt = string::utf8(b"You can perform the following tasks, the task is a specific type of action, it will be executed async:\n");  // 初始化提示字符串：描述任务
        string::append(&mut prompt, string::utf8(b"You can call the task same as the action.\n"));  // 追加说明：任务调用方式
        string::append(&mut prompt, string::utf8(b"The task price is the price of the task, in the unit of RGas.\n"));  // 追加说明：任务价格单位
        let task_spec_json = build_json_section(task_specs);  // 将任务规格转换为 JSON 格式
        string::append(&mut prompt, task_spec_json);  // 将 JSON 追加到提示字符串
        prompt                                // 返回完整的提示字符串
    }

    public fun example_task_specs(resolver: address): TaskSpecifications {  // 定义公开函数：创建示例任务规格集合
        let task_spec = new_task_spec(        // 创建一个示例任务规格
            string::utf8(b"task::hello"),     // 任务名称 "task::hello"
            string::utf8(b"The task description for the AI Agent"),  // 任务描述
            vector[new_task_argument(string::utf8(b"address"), string::utf8(b"string"), string::utf8(b"The sender address"), true)],  // 参数：address，必填
            resolver,                         // 解析者地址
            false,                            // 非链上任务
            decimal_value::new(110000000, 8), // 价格：110000000（8位小数）
        );
        let task_specs = TaskSpecifications {  // 创建任务规格集合
            task_specs: vector[task_spec],    // 包含一个任务规格
        };
        task_specs                            // 返回任务规格集合
    }

    #[test]
    fun test_task_specs_to_json() {           // 定义测试函数：测试任务规格的 JSON 转换
        let task_specs = example_task_specs(@0x1234567890abcdef);  // 创建示例任务规格集合，传入测试地址
        let json_str = task_specs_to_json(&task_specs);  // 将任务规格集合转换为 JSON 字符串
        std::debug::print(&json_str);         // 打印 JSON 字符串（用于调试）
        let task_specs2 = task_specs_from_json(json_str);  // 从 JSON 字符串解析回任务规格集合
        assert!(task_specs == task_specs2, 1);  // 断言：确保转换前后一致
        validate_task_specifications(&task_specs);  // 验证任务规格集合的有效性
    }
}