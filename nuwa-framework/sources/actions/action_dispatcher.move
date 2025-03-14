module nuwa_framework::action_dispatcher {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::vector;                         // 导入标准库中的向量模块
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::object::{Object, ObjectID};  // 导入 MoveOS 标准库中的对象模块，并引入 Object 和 ObjectID 类型
    use moveos_std::result::{Self, is_ok, is_err, err_str, Result};  // 导入 MoveOS 标准库中的结果模块，并引入相关类型和函数
    use nuwa_framework::memory_action;       // 导入 nuwa_framework 中的记忆动作模块
    use nuwa_framework::response_action;     // 导入 nuwa_framework 中的响应动作模块
    use nuwa_framework::transfer_action;     // 导入 nuwa_framework 中的转账动作模块
    use nuwa_framework::task_action;         // 导入 nuwa_framework 中的任务动作模块
    use nuwa_framework::agent::Agent;        // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::string_utils;        // 导入 nuwa_framework 中的字符串工具模块
    use nuwa_framework::action::{ActionDescription, ActionGroup};  // 导入 nuwa_framework 中的动作模块，并引入相关类型
    use nuwa_framework::agent_input::{AgentInputInfo, AgentInputInfoV2};  // 导入 nuwa_framework 中的代理输入模块，并引入相关类型

    /// Error codes                         // 注释：错误码
    const ERROR_INVALID_RESPONSE: u64 = 1;   // 定义错误码：无效响应
    const ERROR_MISSING_ACTION_NAME: u64 = 2;  // 定义错误码：缺少动作名称
    const ERROR_MISSING_ARGS: u64 = 3;       // 定义错误码：缺少参数

    #[data_struct]
    struct ActionCall has copy, drop {       // 定义动作调用结构体，具有 copy 和 drop 能力
        action: String,                      // 动作名称
        /// JSON string containing action-specific arguments  // 注释：包含动作特定参数的 JSON 字符串
        args: String,                        // 参数（JSON 字符串）
    }

    #[data_struct]
    /// Response structure from AI - contains a vector of action calls  // 注释：AI 的响应结构 - 包含动作调用向量
    /// Each action call has:              // 注释：每个动作调用包含：
    /// - "action": specifies the action name, e.g., "memory::add"  // 注释：- "action"：指定动作名称，例如 "memory::add"
    /// - "args": contains a JSON object string with action-specific parameters  // 注释：- "args"：包含动作特定参数的 JSON 对象字符串
    struct ActionResponse has copy, drop {   // 定义动作响应结构体，具有 copy 和 drop 能力
        actions: vector<ActionCall>          // 动作调用列表
    }

    struct ActionEvent has copy, drop, store {  // 定义动作事件结构体，具有 copy、drop 和 store 能力
        action: String,                      // 动作名称
        args: String,                        // 参数
        success: bool,                       // 是否成功
        error: String,                       // 错误信息
    }

    fun init() {                             // 定义初始化函数
        // 当前为空实现
    }

    entry fun register_actions() {           // 定义入口函数：注册动作
        // 当前为空实现
    }

    public fun get_action_groups(): vector<ActionGroup> {  // 定义公开函数：获取动作组
        let groups = vector::empty();        // 初始化空的动作组向量
        let memory_group = memory_action::get_action_group();  // 获取记忆动作组
        vector::push_back(&mut groups, memory_group);  // 添加记忆动作组
        let response_group = response_action::get_action_group();  // 获取响应动作组
        vector::push_back(&mut groups, response_group);  // 添加响应动作组
        let transfer_group = transfer_action::get_action_group();  // 获取转账动作组
        vector::push_back(&mut groups, transfer_group);  // 添加转账动作组
        groups                               // 返回动作组列表
    }

    public fun get_action_descriptions(): vector<ActionDescription> {  // 定义公开函数：获取动作描述
        let descriptions = vector::empty();  // 初始化空的动作描述向量

        // Register memory actions           // 注释：注册记忆动作
        let memory_descriptions = memory_action::get_action_descriptions();  // 获取记忆动作描述
        vector::append(&mut descriptions, memory_descriptions);  // 添加记忆动作描述

        // Register response actions         // 注释：注册响应动作
        let response_descriptions = response_action::get_action_descriptions();  // 获取响应动作描述
        vector::append(&mut descriptions, response_descriptions);  // 添加响应动作描述

        // Register transfer actions         // 注释：注册转账动作
        let transfer_descriptions = transfer_action::get_action_descriptions();  // 获取转账动作描述
        vector::append(&mut descriptions, transfer_descriptions);  // 添加转账动作描述

        descriptions                         // 返回动作描述列表
    }

    /// Dispatch all actions from line-based format  // 注释：从基于行的格式分派所有动作
    public fun dispatch_actions(_agent: &mut Object<Agent>, _response: String) {  // 定义公开函数：分派动作（已废弃）
        abort 0                              // 中止并抛出错误（无具体错误码）
    }

    public fun dispatch_actions_v2(_agent: &mut Object<Agent>, _agent_input: AgentInputInfo, _response: String) {  // 定义公开函数：分派动作 V2（已废弃）
        abort 0                              // 中止并抛出错误（无具体错误码）
    }

    public fun dispatch_actions_v3(agent: &mut Object<Agent>, agent_input: AgentInputInfoV2, response: String) {  // 定义公开函数：分派动作 V3
        let action_response = parse_line_based_response(&response);  // 解析基于行的响应
        let actions = action_response.actions;  // 获取动作列表
        let i = 0;                           // 初始化索引
        let len = vector::length(&actions);  // 获取动作数量
        //TODO the AgentInput always has a response channel?  // 注释：待办事项：AgentInput 总是包含响应通道吗？
        let default_channel_id = response_action::get_default_channel_id_from_input(&agent_input);  // 从输入获取默认通道 ID
        while (i < len) {                    // 遍历动作
            let action_call = vector::borrow(&actions, i);  // 借用当前动作调用
            execute_action(agent, &agent_input, default_channel_id, action_call);  // 执行动作
            i = i + 1;                       // 索引递增
        };
    }

    /// Execute a single action call         // 注释：执行单个动作调用
    fun execute_action(agent: &mut Object<Agent>, agent_input: &AgentInputInfoV2, default_channel_id: ObjectID, action_call: &ActionCall) {  // 定义函数：执行动作
        let action_name = &action_call.action;  // 获取动作名称
        let args = &action_call.args;        // 获取参数
        let skip_event = false;              // 初始化跳过事件标志
        let result: Result<bool,String> = if (string_utils::starts_with(action_name, &b"memory::")) {  // 如果是记忆动作
            let result = memory_action::execute_v3(agent, agent_input, *action_name, *args);  // 执行记忆动作
            if(is_ok(&result)){              // 如果执行成功
                //if the memory action is none, skip the event  // 注释：如果记忆动作是 none，则跳过事件
                let updated_memory:bool = result::unwrap(result);  // 获取更新结果
                if(!updated_memory){         // 如果未更新记忆
                    skip_event = true;       // 设置跳过事件标志
                };
            };
            result                           // 返回结果
        } else if (string_utils::starts_with(action_name, &b"response::")) {  // 如果是响应动作
            //skip all response actions        // 注释：跳过所有响应动作
            skip_event = true;               // 设置跳过事件标志
            response_action::execute_v3(agent, agent_input, *action_name, *args)  // 执行响应动作
        } else if (string_utils::starts_with(action_name, &b"transfer::")) {  // 如果是转账动作
            transfer_action::execute_v3(agent, agent_input, *action_name, *args)  // 执行转账动作
        } else if (string_utils::starts_with(action_name, &b"task::")) {  // 如果是任务动作
            task_action::execute(agent, agent_input, *action_name, *args)  // 执行任务动作
        } else {                             // 如果是未知动作
            err_str(b"Unsupported action")   // 返回错误：不支持的动作
        };
        if (!skip_event) {                   // 如果不跳过事件
            let event = ActionEvent {        // 创建动作事件
                action: *action_name,        // 动作名称
                args: *args,                 // 参数
                success: is_ok(&result),     // 是否成功
                error: if (is_err(&result)) { result::unwrap_err(result) } else { string::utf8(b"") },  // 错误信息
            };
            response_action::send_event_to_channel(agent, default_channel_id, string::utf8(json::to_json(&event)));  // 发送事件到通道
        };
    }

    /// Parse JSON response into ActionResponse  // 注释：将 JSON 响应解析为 ActionResponse
    public fun parse_response(json_str: String): ActionResponse {  // 定义公开函数：解析响应
        json::from_json<ActionResponse>(string::into_bytes(json_str))  // 从 JSON 解析为 ActionResponse
    }
    
    /// Get actions from ActionResponse      // 注释：从 ActionResponse 获取动作
    public fun get_actions(response: &ActionResponse): &vector<ActionCall> {  // 定义公开函数：获取动作列表
        &response.actions                    // 返回动作调用列表的引用
    }

    /// Get action name from ActionCall      // 注释：从 ActionCall 获取动作名称
    public fun get_action_name(action_call: &ActionCall): &String {  // 定义公开函数：获取动作名称
        &action_call.action                  // 返回动作名称的引用
    }

    /// Get action arguments from ActionCall  // 注释：从 ActionCall 获取动作参数
    public fun get_action_args(action_call: &ActionCall): &String {  // 定义公开函数：获取动作参数
        &action_call.args                    // 返回参数的引用
    }

    /// Create an action call with a raw string args  // 注释：使用原始字符串参数创建动作调用
    public fun create_action_call(action: String, args_json: String): ActionCall {  // 定义公开函数：创建动作调用
        ActionCall { action, args: args_json }  // 创建并返回 ActionCall 实例
    }

    /// Create an action call with any serializable args type  // 注释：使用任何可序列化的参数类型创建动作调用
    /// This provides a type-safe way to create action calls  // 注释：这提供了一种类型安全的方式来创建动作调用
    public fun create_action_call_with_object<T: copy + drop>(action: String, args: T): ActionCall {  // 定义公开函数：创建带对象的动作调用
        let args_json = string::utf8(json::to_json(&args));  // 将参数序列化为 JSON 字符串
        ActionCall { action, args: args_json }  // 创建并返回 ActionCall 实例
    }

    /// Create a new empty ActionResponse    // 注释：创建新的空 ActionResponse
    public fun create_empty_response(): ActionResponse {  // 定义公开函数：创建空响应
        ActionResponse { actions: vector::empty() }  // 创建并返回空的 ActionResponse
    }

    /// Add an action to an ActionResponse   // 注释：向 ActionResponse 添加动作
    public fun add_action(response: &mut ActionResponse, action_call: ActionCall) {  // 定义公开函数：添加动作
        vector::push_back(&mut response.actions, action_call);  // 将动作调用添加到响应中
    }

    /// Convert ActionResponse to JSON string  // 注释：将 ActionResponse 转换为 JSON 字符串
    public fun response_to_json(response: &ActionResponse): String {  // 定义公开函数：响应转 JSON
        string::utf8(json::to_json(response))  // 将响应序列化为 JSON 字符串并返回
    }    

    /// Create an ActionResponse from a vector of ActionCalls  // 注释：从动作调用向量创建 ActionResponse
    public fun create_action_response(actions: vector<ActionCall>): ActionResponse {  // 定义公开函数：创建动作响应
        ActionResponse { actions }           // 创建并返回 ActionResponse
    }

    /// Parse a line-based response string into an ActionResponse  // 注释：将基于行的响应字符串解析为 ActionResponse
    public fun parse_line_based_response(response: &String): ActionResponse {  // 定义公开函数：解析基于行的响应
        let actions = vector::empty<ActionCall>();  // 初始化空的动作调用向量
        let lines = string_utils::split(response, &string::utf8(b"\n"));  // 按换行符分割响应
        
        let i = 0;                           // 初始化索引
        let len = vector::length(&lines);    // 获取行数
        
        while (i < len) {                    // 遍历每一行
            let line = string_utils::trim(vector::borrow(&lines, i));  // 去除行首尾空白
            
            if (!string::is_empty(&line)) {  // 如果行不为空
                // Find the first space to separate action name from parameters  // 注释：查找第一个空格以分隔动作名称和参数
                let line_bytes = string::bytes(&line);  // 获取行字节
                let line_len = vector::length(line_bytes);  // 获取行长度
                let j = 0;                       // 初始化子索引
                let found_space = false;         // 初始化空格标志
                
                while (j < line_len && !found_space) {  // 查找第一个空格
                    if (*vector::borrow(line_bytes, j) == 0x20) {  // 空格字符（ASCII 32）
                        found_space = true;      // 找到空格
                    } else {
                        j = j + 1;               // 子索引递增
                    }
                };
                
                if (found_space && j < line_len) {  // 如果找到空格且未到行尾
                    let action = string::utf8(string_utils::get_substr(line_bytes, 0, j));  // 提取动作名称
                    let args = string::utf8(string_utils::get_substr(line_bytes, j + 1, line_len));  // 提取参数
                    
                    // Remove any extra spaces       // 注释：移除多余空格
                    let trimmed_action = string_utils::trim(&action);  // 修剪动作名称
                    let trimmed_args = string_utils::trim(&args);  // 修剪参数
                    
                    if (!string::is_empty(&trimmed_action) && !string::is_empty(&trimmed_args)) {  // 如果动作和参数都不为空
                        // Check for JSON format in args  // 注释：检查参数是否为 JSON 格式
                        if (string::index_of(&trimmed_args, &string::utf8(b"{")) == 0) {  // 如果以 '{' 开头
                            let action_call = create_action_call(trimmed_action, trimmed_args);  // 创建动作调用
                            vector::push_back(&mut actions, action_call);  // 添加到动作列表
                        }
                    }
                }
            };
            i = i + 1;                       // 索引递增
        };
        
        ActionResponse { actions }           // 返回解析出的 ActionResponse
    }

    /// Convert ActionResponse to string format  // 注释：将 ActionResponse 转换为字符串格式
    public fun response_to_str(response: &ActionResponse): String {  // 定义公开函数：响应转字符串
        let result = string::utf8(b"");      // 初始化空字符串
        let actions = &response.actions;     // 获取动作列表
        let len = vector::length(actions);   // 获取动作数量
        let i = 0;                           // 初始化索引
        
        while (i < len) {                    // 遍历动作
            let action_call = vector::borrow(actions, i);  // 借用当前动作调用
            
            // Add action name               // 注释：添加动作名称
            string::append(&mut result, action_call.action);  // 追加动作名称
            string::append(&mut result, string::utf8(b" "));  // 追加空格
            
            // Add parameters                // 注释：添加参数
            string::append(&mut result, action_call.args);  // 追加参数
            
            // Add newline if not the last action  // 注释：如果不是最后一个动作，添加换行符
            if (i + 1 < len) {               // 如果不是最后一个动作
                string::append(&mut result, string::utf8(b"\n"));  // 追加换行符
            };
            
            i = i + 1;                       // 索引递增
        };
        
        result                               // 返回结果字符串
    }

    #[test_only]
    public fun init_for_test() {             // 定义仅测试函数：测试初始化
        init();                              // 调用初始化函数
    }

    #[test]
    fun test_dispatch_actions() {            // 定义测试函数：测试分派动作
        use nuwa_framework::agent;           // 使用代理模块
        use nuwa_framework::action;          // 使用动作模块
        use nuwa_framework::memory;          // 使用记忆模块
        use nuwa_framework::memory_action;   // 使用记忆动作模块
        use nuwa_framework::response_action;  // 使用响应动作模块
        use nuwa_framework::transfer_action;  // 使用转账动作模块
        use nuwa_framework::channel;         // 使用通道模块
        use nuwa_framework::agent_input;     // 使用代理输入模块
        use nuwa_framework::message;         // 使用消息模块

        // Initialize                    // 注释：初始化
        nuwa_framework::character_registry::init_for_test();  // 为测试初始化角色注册表
        action::init_for_test();             // 为测试初始化动作模块
        memory_action::register_actions();   // 注册记忆动作
        response_action::register_actions();  // 注册响应动作
        transfer_action::register_actions();  // 注册转账动作

        let (agent, cap) = agent::create_test_agent();  // 创建测试代理和能力对象
        let test_addr = @0x42;               // 定义测试地址

        let channel_id = channel::create_ai_home_channel(agent);  // 创建 AI 主通道
        // Using type-specific constructors with serialization  // 注释：使用类型特定的构造函数和序列化
        let memory_args = memory_action::create_remember_user_args(  // 创建记住用户参数
            string::utf8(b"User prefers detailed explanations"),  // 用户偏