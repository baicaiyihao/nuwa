module nuwa_framework::response_action {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::option;                         // 导入标准库中的选项模块
    use std::vector;                         // 导入标准库中的向量模块
    use moveos_std::object::{Self, Object, ObjectID};  // 导入 MoveOS 标准库中的对象模块，并引入 Object 和 ObjectID 类型
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::result::{ok, err_str, Result};  // 导入 MoveOS 标准库中的结果模块，并引入相关类型和函数
    use moveos_std::copyable_any;            // 导入 MoveOS 标准库中的可复制任意类型模块
    use nuwa_framework::agent::{Self, Agent};  // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::action;              // 导入 nuwa_framework 中的动作模块
    use nuwa_framework::channel;             // 导入 nuwa_framework 中的通道模块
    use nuwa_framework::action::{ActionDescription, ActionGroup};  // 导入 nuwa_framework 中的动作模块，并引入相关类型
    use nuwa_framework::agent_input::{Self, AgentInputInfoV2};  // 导入 nuwa_framework 中的代理输入模块，并引入 AgentInputInfoV2 类型
    use nuwa_framework::message::{Self, MessageInputV3};  // 导入 nuwa_framework 中的消息模块，并引入 MessageInputV3 类型

    friend nuwa_framework::action_dispatcher;  // 声明 action_dispatcher 模块为友元模块
    friend nuwa_framework::task_action;      // 声明 task_action 模块为友元模块

    // Action names                         // 注释：动作名称
    const ACTION_NAME_CHANNEL_MESSAGE: vector<u8> = b"response::channel_message";  // 定义常量：通道消息动作名称
    public fun action_name_channel_message(): String {  // 定义公开函数：返回通道消息动作名称
        string::utf8(ACTION_NAME_CHANNEL_MESSAGE)  // 返回字符串形式的动作名称
    }
    const ACTION_NAME_DIRECT_MESSAGE: vector<u8> = b"response::direct_message";  // 定义常量：直接消息动作名称
    public fun action_name_direct_message(): String {  // 定义公开函数：返回直接消息动作名称
        string::utf8(ACTION_NAME_DIRECT_MESSAGE)  // 返回字符串形式的动作名称
    }
    
    // Action examples                      // 注释：动作示例
    const CHANNEL_MESSAGE_EXAMPLE: vector<u8> = b"{\"channel_id\":\"0x01374a879f3fd3a79be9c776b3f36adb2eedf298beed3900db77347065eb59e5d6\",\"content\":\"I understand you prefer detailed explanations.\"}";  // 定义常量：通道消息示例
    const DIRECT_MESSAGE_EXAMPLE: vector<u8> = b"{\"recipient\":\"rooch1a47ny79da3tthtnclcdny4xtadhaxcmqlnpfthf3hqvztkphcqssqd8edv\",\"content\":\"This is a direct message.\"}";  // 定义常量：直接消息示例

    //TODO remove this struct when we prepare a break upgrade  // 注释：待办事项：在准备重大升级时移除此结构体
    #[data_struct]
    /// Arguments for the say action (sending a message to a channel)  // 注释：say 动作的参数（发送消息到通道）
    struct SayActionArgs has copy, drop {    // 定义 say 动作参数结构体，具有 copy 和 drop 能力
        //TODO change to ObjectID after #https://github.com/rooch-network/rooch/issues/3362 is resolved  // 注释：待办事项：在问题 #3362 解决后改为 ObjectID
        channel_id: String,                  // 通道 ID（字符串形式）
        content: String,                     // 响应内容
    }

    public fun create_say_args(              // 定义公开函数：创建 say 动作参数（已废弃）
        _channel_id: ObjectID,               // 通道 ID
        _content: String                     // 内容
    ): SayActionArgs {                       // 返回 SayActionArgs 类型
       abort 0                              // 中止并抛出错误（无具体错误码）
    }

    //TODO remove this when we prepare a break upgrade  // 注释：待办事项：在准备重大升级时移除此结构体
    #[data_struct]
    /// Arguments for sending a message to a channel  // 注释：发送通道消息的参数
    struct ChannelMessageArgs has copy, drop {  // 定义通道消息参数结构体，具有 copy 和 drop 能力
        channel_id: String,                  // 通道 ID（字符串形式）
        content: String,                     // 消息内容
    }

    #[data_struct]
    /// Arguments for sending a message to a channel  // 注释：发送通道消息的参数
    struct ChannelMessageArgsV2 has copy, drop {  // 定义通道消息参数结构体 V2，具有 copy 和 drop 能力
        channel_id: ObjectID,                // 通道 ID（对象 ID 形式）
        content: String,                     // 消息内容
    }

    #[data_struct]
    /// Arguments for sending a private message to a user  // 注释：发送私人消息给用户的参数
    struct DirectMessageArgs has copy, drop {  // 定义直接消息参数结构体，具有 copy 和 drop 能力
        recipient: address,                  // 接收者地址
        content: String,                     // 消息内容
    }

    /// Create arguments for channel message action  // 注释：创建通道消息动作参数
    public fun create_channel_message_args(  // 定义公开函数：创建通道消息参数（已废弃）
        _channel_id: ObjectID,               // 通道 ID
        _content: String                     // 内容
    ): ChannelMessageArgs {                  // 返回 ChannelMessageArgs 类型
        abort 0                              // 中止并抛出错误（无具体错误码）
    }

    public fun create_channel_message_args_v2(  // 定义公开函数：创建通道消息参数 V2
        channel_id: ObjectID,                // 通道 ID
        content: String                      // 内容
    ): ChannelMessageArgsV2 {                // 返回 ChannelMessageArgsV2 类型
        ChannelMessageArgsV2 {               // 创建并返回 ChannelMessageArgsV2 实例
            channel_id,                      // 通道 ID
            content                          // 内容
        }
    }

    /// Create arguments for direct message action  // 注释：创建直接消息动作参数
    public fun create_direct_message_args(   // 定义公开函数：创建直接消息参数
        recipient: address,                  // 接收者地址
        content: String                      // 内容
    ): DirectMessageArgs {                   // 返回 DirectMessageArgs 类型
        DirectMessageArgs {                  // 创建并返回 DirectMessageArgs 实例
            recipient,                       // 接收者
            content                          // 内容
        }
    }

    /// Register all response actions       // 注释：注册所有响应动作
    public fun register_actions() {          // 定义公开函数：注册动作
        //TODO remove this when we prepare a break upgrade  // 注释：待办事项：在准备重大升级时移除此函数
    }

    public fun get_action_group(): ActionGroup {  // 定义公开函数：获取动作组
        let description = string::utf8(b"Actions related to responding to user queries, you can use multiple response actions to send messages to channels or users.\n\n");  // 初始化描述
        string::append(&mut description, string::utf8(b"CRITICAL: You MUST ALWAYS send at least one response back to the current message using either:\n"));  // 添加关键提示
        string::append(&mut description, string::utf8(b"- response::channel_message to the current channel if in a channel conversation\n"));  // 添加通道消息提示
        string::append(&mut description, string::utf8(b"- response::direct_message to the current user if in a direct message conversation\n"));  // 添加直接消息提示
        //string::append(&mut description, string::utf8(b"\nFailure to respond to the current message will result in your actions not being processed.\n"));  // 注释掉的失败提示
        
        action::new_action_group(            // 创建并返回动作组
            string::utf8(b"response"),       // 命名空间：response
            description,                     // 描述
            get_action_descriptions()        // 动作描述列表
        )   
    }

    /// Get descriptions for all response actions  // 注释：获取所有响应动作的描述
    public fun get_action_descriptions(): vector<ActionDescription> {  // 定义公开函数：获取动作描述
        let descriptions = vector::empty();  // 初始化空的动作描述向量

        // Register channel message action   // 注释：注册通道消息动作
        let channel_args = vector[           // 创建通道消息动作参数列表
            action::new_action_argument(     // 创建参数：通道 ID
                string::utf8(b"channel_id"), // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The channel to send message to"),  // 描述
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 创建参数：内容
                string::utf8(b"content"),    // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The message content"),  // 描述
                true,                        // 是否必需
            ),
        ];

        vector::push_back(&mut descriptions,  // 添加通道消息动作描述
            action::new_action_description(
                string::utf8(ACTION_NAME_CHANNEL_MESSAGE),  // 动作名称
                string::utf8(b"Send a message to the channel"),  // 描述
                channel_args,                // 参数列表
                string::utf8(CHANNEL_MESSAGE_EXAMPLE),  // 参数示例
                string::utf8(b"Use this action to send a message to all participants in a specific channel"),  // 使用提示
                string::utf8(b"This message will be visible to everyone in the channel"),  // 约束
            )
        );

        // Register direct message action    // 注释：注册直接消息动作
        let dm_args = vector[                // 创建直接消息动作参数列表
            action::new_action_argument(     // 创建参数：接收者
                string::utf8(b"recipient"),  // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The recipient address to send message to"),  // 描述
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 创建参数：内容
                string::utf8(b"content"),    // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The message content"),  // 描述
                true,                        // 是否必需
            ),
        ];

        vector::push_back(&mut descriptions,  // 添加直接消息动作描述
            action::new_action_description(
                string::utf8(ACTION_NAME_DIRECT_MESSAGE),  // 动作名称
                string::utf8(b"Send a direct message to a user"),  // 描述
                dm_args,                     // 参数列表
                string::utf8(DIRECT_MESSAGE_EXAMPLE),  // 参数示例
                string::utf8(b"Use this action to send a message directly to a specific user"),  // 使用提示
                string::utf8(b"The message is onchain, so it is visible to everyone"),  // 约束
            )
        );

        descriptions                         // 返回动作描述列表
    }

    public fun execute(_agent: &mut Object<Agent>, _action_name: String, _args_json: String) {  // 定义公开函数：执行动作（已废弃）
        abort 0                              // 中止并抛出错误（无具体错误码）
    }

    /// Execute a response action           // 注释：执行响应动作
    public fun execute_v3(agent: &mut Object<Agent>, _agent_input: &AgentInputInfoV2, action_name: String, args_json: String): Result<bool, String> {  // 定义公开函数：执行动作 V3
        if (action_name == string::utf8(ACTION_NAME_CHANNEL_MESSAGE)) {  // 如果是通道消息动作
            // Handle channel message action  // 注释：处理通道消息动作
            let args_opt = json::from_json_option<ChannelMessageArgsV2>(string::into_bytes(args_json));  // 从 JSON 解析参数
            if (option::is_none(&args_opt)) {  // 如果参数解析失败
                return err_str(b"Invalid arguments for channel message action")  // 返回错误：无效参数
            };
            let args = option::destroy_some(args_opt);  // 提取解析出的参数
            send_channel_message(agent, args.channel_id, args.content);  // 发送通道消息
            ok(true)                         // 返回成功结果
        } else if (action_name == string::utf8(ACTION_NAME_DIRECT_MESSAGE)) {  // 如果是直接消息动作
            // Handle direct message action   // 注释：处理直接消息动作
            let args_opt = json::from_json_option<DirectMessageArgs>(string::into_bytes(args_json));  // 从 JSON 解析参数
            if (option::is_none(&args_opt)) {  // 如果参数解析失败
                return err_str(b"Invalid arguments for direct message action")  // 返回错误：无效参数
            };
            let args = option::destroy_some(args_opt);  // 提取解析出的参数
            send_direct_message(agent, args.recipient, args.content);  // 发送直接消息
            ok(true)                         // 返回成功结果
        } else {
            err_str(b"Unsupported action")      // 返回错误：不支持的动作
        }
    }

    /// Send a message to a channel         // 注释：发送消息到通道
    fun send_channel_message(agent: &mut Object<Agent>, channel_id: ObjectID, content: String): ObjectID {  // 定义函数：发送通道消息
        let channel = object::borrow_mut_object_shared<channel::Channel>(channel_id);  // 借用共享的可变通道对象
        let agent_addr = agent::get_agent_address(agent);  // 获取代理地址
        channel::add_ai_response(channel, content, agent_addr);  // 添加 AI 响应到通道
        channel_id                           // 返回通道 ID
    }

    /// Send a direct message to a specific user  // 注释：发送直接消息给特定用户
    fun send_direct_message(agent: &mut Object<Agent>, recipient: address, content: String): ObjectID {  // 定义函数：发送直接消息
        channel::send_ai_direct_message(agent, recipient, content)  // 调用通道模块发送 AI 直接消息
    }

    public(friend) fun get_default_channel_id_from_input(agent_input: &AgentInputInfoV2): ObjectID {  // 定义友元函数：从输入获取默认通道 ID
        let message_input_any = *agent_input::get_input_data_from_info_v2(agent_input);  // 获取输入数据（任意类型）
        //TODO add a try unpack function      // 注释：待办事项：添加尝试解包函数
        let message_input = copyable_any::unpack<MessageInputV3>(message_input_any);  // 解包为 MessageInputV3
        message::get_channel_id_from_input(&message_input)  // 从消息输入获取通道 ID
    }

    public(friend) fun send_event_to_channel(agent: &mut Object<Agent>, channel_id: ObjectID, event: String) {  // 定义友元函数：发送事件到通道
        let channel = object::borrow_mut_object_shared<channel::Channel>(channel_id);  // 借用共享的可变通道对象
        let agent_addr = agent::get_agent_address(agent);  // 获取代理地址
        channel::add_ai_event(channel, event, agent_addr);  // 添加 AI 事件到通道
    }

    #[test]
    fun test_response_action_examples() {    // 定义测试函数：测试响应动作示例
        // Test channel message example       // 注释：测试通道消息示例
        let channel_args = json::from_json<ChannelMessageArgsV2>(CHANNEL_MESSAGE_EXAMPLE);  // 从 JSON 示例解析通道消息参数
        assert!(channel_args.channel_id == object::from_string(&string::utf8(b"0x01374a879f3fd3a79be9c776b3f36adb2eedf298beed3900db77347065eb59e5d6")), 1);  // 断言：通道 ID 正确
        assert!(channel_args.content == string::utf8(b"I understand you prefer detailed explanations."), 2);  // 断言：内容正确
        
        // Test direct message example        // 注释：测试直接消息示例
        let dm_args = json::from_json<DirectMessageArgs>(DIRECT_MESSAGE_EXAMPLE);  // 从 JSON 示例解析直接消息参数
        assert!(dm_args.recipient == @0xed7d3278adec56bbae78fe1b3254cbeb6fd36360fcc295dd31b81825d837c021, 3);  // 断言：接收者地址正确
        assert!(dm_args.content == string::utf8(b"This is a direct message."), 4);  // 断言：内容正确
    }

    #[test]
    fun test_channel_id_conversion() {       // 定义测试函数：测试通道 ID 转换
        use nuwa_framework::string_utils::{string_to_channel_id, channel_id_to_string};  // 导入字符串工具函数
        let channel_id = object::named_object_id<channel::Channel>();  // 获取命名通道对象 ID
        let channel_id_str = channel_id_to_string(channel_id);  // 将通道 ID 转换为字符串
        std::debug::print(&channel_id_str);  // 打印字符串形式的通道 ID（调试用）
        let channel_id_converted = string_to_channel_id(channel_id_str);  // 将字符串转换回通道 ID
        assert!(channel_id == channel_id_converted, 0);  // 断言：转换前后 ID 相等
    }
}