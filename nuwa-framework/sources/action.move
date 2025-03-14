module nuwa_framework::action {
    use std::string::String;                 // 导入标准库中的字符串模块，并引入 String 类型
    use std::vector;                         // 导入标准库中的向量模块
    use std::option;                         // 导入标准库中的选项模块
    use moveos_std::table::{Self, Table};    // 导入 MoveOS 标准库中的表模块，并引入 Table 类型
    use moveos_std::object;                  // 导入 MoveOS 标准库中的对象模块

    #[data_struct]
    struct ActionGroup has copy, drop, store {  // 定义动作组结构体，具有 copy、drop、store 能力
        namespace: String,                   // 命名空间
        description: String,                 // 描述
        actions: vector<ActionDescription>,  // 动作描述列表
    }
    
    #[data_struct]
    /// Action description for AI             // 注释：AI 的动作描述
    struct ActionDescription has copy, drop, store {  // 定义动作描述结构体，具有 copy、drop、store 能力
        name: String,                        // 动作名称
        description: String,                 // 描述
        args: vector<ActionArgument>,        // 参数列表
        args_example: String,                // 参数示例（JSON 格式）
        usage_hint: String,                  // 使用提示（何时及如何使用）
        constraints: String,                 // 约束（要求和限制）
    }

    #[data_struct]
    struct ActionArgument has copy, drop, store {  // 定义动作参数结构体，具有 copy、drop、store 能力
        name: String,                        // 参数名称
        type_desc: String,                   // 类型描述
        description: String,                 // 描述
        required: bool,                      // 是否必需
    }

    struct ActionRegistry has key {          // 定义动作注册表结构体，具有 key 能力
        // Store action descriptions by type_info and name  // 注释：按类型信息和名称存储动作描述
        descriptions: Table<String, ActionDescription>,  // 动作描述表（键为名称，值为描述）
    }

    const ERROR_ACTION_ALREADY_REGISTERED: u64 = 1;  // 定义错误码：动作已注册
    const ERROR_ACTION_NOT_FOUND: u64 = 2;   // 定义错误码：动作未找到

    fun init() {                             // 定义函数：初始化动作注册表
        let registry = ActionRegistry {      // 创建 ActionRegistry 实例
            descriptions: table::new(),      // 初始化空的动作描述表
        };
        let registry_obj = object::new_named_object(registry);  // 创建命名对象
        object::to_shared(registry_obj);     // 将对象设置为共享对象
    }

    fun borrow_mut_registry(): &mut ActionRegistry {  // 定义函数：借用可变的动作注册表
        let registry_obj_id = object::named_object_id<ActionRegistry>();  // 获取注册表的命名对象 ID
        let registry_obj = object::borrow_mut_object_extend<ActionRegistry>(registry_obj_id);  // 借用可变的对象
        object::borrow_mut(registry_obj)     // 返回注册表的引用
    }

    /// Register a new action with its description  // 注释：注册新动作及其描述
    public fun register_action(              // 定义公开函数：注册动作
        name: String,                        // 动作名称
        description: String,                 // 描述
        args: vector<ActionArgument>,        // 参数列表
        args_example: String,                // 参数示例
        usage_hint: String,                  // 使用提示
        constraints: String,                 // 约束
    ) {
        let registry = borrow_mut_registry();  // 借用可变的注册表
        assert!(!table::contains(&registry.descriptions, name), ERROR_ACTION_ALREADY_REGISTERED);  // 断言：确保动作未注册，否则抛出已注册错误

        let action_desc = new_action_description(  // 创建动作描述
            name,
            description,
            args,
            args_example,
            usage_hint,
            constraints,
        );
        table::add(&mut registry.descriptions, name, action_desc);  // 将动作描述添加到表中
    }

    /// Create a new action argument         // 注释：创建新动作参数
    public fun new_action_argument(          // 定义公开函数：创建动作参数
        name: String,                        // 参数名称
        type_desc: String,                   // 类型描述
        description: String,                 // 描述
        required: bool,                      // 是否必需
    ): ActionArgument {                      // 返回 ActionArgument 类型
        ActionArgument {                     // 创建并返回 ActionArgument 实例
            name,                            // 名称
            type_desc,                       // 类型描述
            description,                     // 描述
            required,                        // 是否必需
        }
    }

    public fun new_action_description(       // 定义公开函数：创建动作描述
        name: String,                        // 动作名称
        description: String,                 // 描述
        args: vector<ActionArgument>,        // 参数列表
        args_example: String,                // 参数示例
        usage_hint: String,                  // 使用提示
        constraints: String,                 // 约束
    ): ActionDescription {                   // 返回 ActionDescription 类型
        ActionDescription {                  // 创建并返回 ActionDescription 实例
            name,                            // 名称
            description,                     // 描述
            args,                            // 参数
            args_example,                    // 参数示例
            usage_hint,                      // 使用提示
            constraints,                     // 约束
        }
    }

    public fun new_action_group(             // 定义公开函数：创建动作组
        namespace: String,                   // 命名空间
        description: String,                 // 描述
        actions: vector<ActionDescription>,  // 动作描述列表
    ): ActionGroup {                         // 返回 ActionGroup 类型
        ActionGroup {                        // 创建并返回 ActionGroup 实例
            namespace,                       // 命名空间
            description,                     // 描述
            actions,                         // 动作列表
        }
    }

    /// Get all registered action descriptions  // 注释：获取所有已注册的动作描述
    public fun get_all_action_descriptions(): vector<ActionDescription> {  // 定义公开函数：获取所有动作描述
        let registry = borrow_mut_registry();  // 借用可变的注册表
        let descriptions = vector::empty();  // 初始化空的描述向量
        
        let iter = table::list_field_keys(&registry.descriptions, option::none(), 100);  // 创建迭代器，列出表中的键（最多 100 个）
        while (table::field_keys_len(&iter) > 0) {  // 当仍有键未处理时
            let (_key, value) = table::next(&mut iter);  // 获取下一个键值对
            vector::push_back(&mut descriptions, *value);  // 将值（动作描述）添加到向量
        };
        
        descriptions                         // 返回所有动作描述
    }

    /// Get action descriptions for the specified keys  // 注释：获取指定键的动作描述
    public fun get_action_descriptions(keys: &vector<String>): vector<ActionDescription> {  // 定义公开函数：获取指定动作描述
        let registry = borrow_mut_registry();  // 借用可变的注册表
        let descriptions = vector::empty();  // 初始化空的描述向量
        let i = 0;                           // 初始化索引
        let len = vector::length(keys);      // 获取键列表长度
        
        while (i < len) {                    // 遍历键列表
            let key = vector::borrow(keys, i);  // 借用当前键
            if (table::contains(&registry.descriptions, *key)) {  // 如果表中包含该键
                let desc = table::borrow(&registry.descriptions, *key);  // 借用对应的动作描述
                vector::push_back(&mut descriptions, *desc);  // 添加到描述向量
            };
            i = i + 1;                       // 索引递增
        };
        
        descriptions                         // 返回动作描述列表
    }

    /// Get description for specific action   // 注释：获取特定动作的描述
    public fun get_action_description(name: &String): ActionDescription {  // 定义公开函数：获取特定动作描述
        let registry = borrow_mut_registry();  // 借用可变的注册表
        assert!(table::contains(&registry.descriptions, *name), ERROR_ACTION_NOT_FOUND);  // 断言：确保动作存在，否则抛出未找到错误
        *table::borrow(&registry.descriptions, *name)  // 返回动作描述
    }

    /// Getter functions for ActionDescription  // 注释：ActionDescription 的获取函数
    public fun get_name(action: &ActionDescription): &String {  // 定义公开函数：获取动作名称
        &action.name                         // 返回名称的引用
    }

    public fun get_description(action: &ActionDescription): &String {  // 定义公开函数：获取动作描述
        &action.description                  // 返回描述的引用
    }

    public fun get_args(action: &ActionDescription): &vector<ActionArgument> {  // 定义公开函数：获取动作参数
        &action.args                         // 返回参数列表的引用
    }

    public fun get_args_example(action: &ActionDescription): &String {  // 定义公开函数：获取参数示例
        &action.args_example                 // 返回参数示例的引用
    }

    public fun get_usage_hint(action: &ActionDescription): &String {  // 定义公开函数：获取使用提示
        &action.usage_hint                   // 返回使用提示的引用
    }

    public fun get_constraints(action: &ActionDescription): &String {  // 定义公开函数：获取约束
        &action.constraints                  // 返回约束的引用
    }

    // Add getters for ActionArgument         // 注释：添加 ActionArgument 的获取函数
    public fun get_arg_name(arg: &ActionArgument): &String {  // 定义公开函数：获取参数名称
        &arg.name                            // 返回名称的引用
    }

    public fun get_arg_type_desc(arg: &ActionArgument): &String {  // 定义公开函数：获取参数类型描述
        &arg.type_desc                       // 返回类型描述的引用
    }

    public fun get_arg_description(arg: &ActionArgument): &String {  // 定义公开函数：获取参数描述
        &arg.description                     // 返回描述的引用
    }

    public fun get_arg_required(arg: &ActionArgument): bool {  // 定义公开函数：获取参数是否必需
        arg.required                         // 返回是否必需的布尔值
    }

    public fun get_actions_from_group(group: &ActionGroup): &vector<ActionDescription> {  // 定义公开函数：从动作组获取动作列表
        &group.actions                       // 返回动作列表的引用
    }

    #[test]
    public fun init_for_test() {             // 定义测试函数：为测试初始化
        init();                              // 调用初始化函数
    }

    #[test]
    fun test_register_memory_action() {      // 定义测试函数：测试注册记忆动作
        use std::string;                     // 在测试中使用标准字符串模块
        init_for_test();                     // 为测试初始化
        
        // Register a memory action           // 注释：注册一个记忆动作
        let args = vector[                   // 创建参数列表
            new_action_argument(             // 创建一个参数
                string::utf8(b"content"),    // 参数名称：content
                string::utf8(b"string"),     // 类型描述：string
                string::utf8(b"Memory content"),  // 描述：记忆内容
                true,                        // 是否必需：是
            )
        ];

        register_action(                     // 注册动作
            string::utf8(b"add_memory"),     // 动作名称：add_memory
            string::utf8(b"Add a new memory"),  // 描述：添加新记忆
            args,                            // 参数列表
            string::utf8(b"{\"action\":\"add_memory\",\"args\":[\"test memory\"]}"),  // 参数示例
            string::utf8(b"Use this action to add a new memory"),  // 使用提示
            string::utf8(b"Memory content must be a non-empty string"),  // 约束
        );

        // Verify registration               // 注释：验证注册
        let desc = get_action_description(&string::utf8(b"add_memory"));  // 获取动作描述
        assert!(desc.name == string::utf8(b"add_memory"), 1);  // 断言：名称正确
    }

    #[test]
    fun test_get_action_descriptions() {     // 定义测试函数：测试获取动作描述
        use std::string;                     // 在测试中使用标准字符串模块
        init_for_test();                     // 为测试初始化
        
        // Register a test action            // 注释：注册一个测试动作
        let args = vector[                   // 创建参数列表
            new_action_argument(             // 创建一个参数
                string::utf8(b"content"),    // 参数名称：content
                string::utf8(b"string"),     // 类型描述：string
                string::utf8(b"Memory content"),  // 描述：记忆内容
                true,                        // 是否必需：是
            )
        ];

        register_action(                     // 注册动作
            string::utf8(b"add_memory"),     // 动作名称：add_memory
            string::utf8(b"Add a new memory"),  // 描述：添加新记忆
            args,                            // 参数列表
            string::utf8(b"{\"action\":\"add_memory\",\"args\":[\"test memory\"]}"),  // 参数示例
            string::utf8(b"Use this action to add a new memory"),  // 使用提示
            string::utf8(b"Memory content must be a non-empty string"),  // 约束
        );

        let action_key = string::utf8(b"add_memory");  // 定义动作键
        
        // Get descriptions using the key    // 注释：使用键获取描述
        let keys = vector::singleton(action_key);  // 创建包含单个键的向量
        let descriptions = get_action_descriptions(&keys);  // 获取动作描述
        
        assert!(vector::length(&descriptions) == 1, 1);  // 断言：返回的描述数量为 1
        let desc = vector::borrow(&descriptions, 0);  // 借用第一个描述
        assert!(desc.name == string::utf8(b"add_memory"), 2);  // 断言：名称正确
    }

    #[test]
    fun test_get_all_action_descriptions() {  // 定义测试函数：测试获取所有动作描述
        use std::string;                     // 在测试中使用标准字符串模块
        init_for_test();                     // 为测试初始化
        
        // Register test actions             // 注释：注册测试动作
        let memory_args = vector[            // 创建记忆动作的参数列表
            new_action_argument(             // 创建一个参数
                string::utf8(b"target"),     // 参数名称：target
                string::utf8(b"address"),    // 类型描述：address
                string::utf8(b"The target address"),  // 描述：目标地址
                true,                        // 是否必需：是
            )
        ];

        let response_args = vector[          // 创建响应动作的参数列表
            new_action_argument(             // 创建一个参数
                string::utf8(b"content"),    // 参数名称：content
                string::utf8(b"string"),     // 类型描述：string
                string::utf8(b"Response content"),  // 描述：响应内容
                true,                        // 是否必需：是
            )
        ];

        register_action(                     // 注册记忆动作
            string::utf8(b"memory::add"),    // 动作名称：memory::add
            string::utf8(b"Add a new memory"),  // 描述：添加新记忆
            memory_args,                     // 参数列表
            string::utf8(b"{\"action\":\"memory::add\",\"args\":[\"0x123\",\"test memory\"]}"),  // 参数示例
            string::utf8(b"Use this action to store memories"),  // 使用提示
            string::utf8(b"Target must be valid address"),  // 约束
        );

        register_action(                     // 注册响应动作
            string::utf8(b"response::say"),  // 动作名称：response::say
            string::utf8(b"Send a response"),  // 描述：发送响应
            response_args,                   // 参数列表
            string::utf8(b"{\"action\":\"response::say\",\"args\":[\"hello\"]}"),  // 参数示例
            string::utf8(b"Use this action to respond"),  // 使用提示
            string::utf8(b"Content must not be empty"),  // 约束
        );

        // Get all descriptions              // 注释：获取所有描述
        let descriptions = get_all_action_descriptions();  // 获取所有动作描述
        
        // Verify we got both actions        // 注释：验证获取了两个动作
        assert!(vector::length(&descriptions) == 2, 1);  // 断言：返回的描述数量为 2
        
        // Verify action names               // 注释：验证动作名称
        let found_memory = false;            // 初始化记忆动作找到标志
        let found_response = false;          // 初始化响应动作找到标志
        let i = 0;                           // 初始化索引
        while (i < vector::length(&descriptions)) {  // 遍历描述列表
            let desc = vector::borrow(&descriptions, i);  // 借用当前描述
            if (desc.name == string::utf8(b"memory::add")) {  // 如果是记忆动作
                found_memory = true;         // 设置找到标志
            };
            if (desc.name == string::utf8(b"response::say")) {  // 如果是响应动作
                found_response = true;       // 设置找到标志
            };
            i = i + 1;                       // 索引递增
        };
        
        assert!(found_memory && found_response, 2);  // 断言：两个动作都找到
    }
}