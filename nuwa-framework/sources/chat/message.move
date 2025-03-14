module nuwa_framework::message {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::vector;                         // 导入标准库中的向量模块
    use moveos_std::timestamp;               // 导入 MoveOS 标准库中的时间戳模块
    use moveos_std::object::{Self, ObjectID};  // 导入 MoveOS 标准库中的对象模块，并引入 ObjectID 类型

    use nuwa_framework::agent_input::{Self, AgentInput};  // 导入 nuwa_framework 中的代理输入模块，并引入 AgentInput 类型
    use nuwa_framework::string_utils::{channel_id_to_string};  // 导入 nuwa_framework 中的字符串工具模块，并引入 channel_id_to_string 函数
    use nuwa_framework::address_utils;       // 导入 nuwa_framework 中的地址工具模块

    friend nuwa_framework::channel;          // 声明 channel 模块为友元模块

    /// Message types                        // 注释：消息类型
    const MESSAGE_TYPE_NORMAL: u8 = 0;       // 定义常量：普通消息类型
    public fun type_normal(): u8 { MESSAGE_TYPE_NORMAL }  // 定义公开函数：返回普通消息类型
    //TODO change this to 1 after            // 注释：待办事项：之后将此改为 1
    const MESSAGE_TYPE_ACTION_EVENT: u8 = 2;  // 定义常量：动作事件消息类型
    public fun type_action_event(): u8 { MESSAGE_TYPE_ACTION_EVENT }  // 定义公开函数：返回动作事件消息类型

    /// The message object structure         // 注释：消息对象结构
    /// The message object is owned by the sender  // 注释：消息对象由发送者拥有
    /// But it is no `store` ability, so the owner can't transfer it to another account  // 注释：但没有 store 能力，因此拥有者无法转移到其他账户
    struct Message has key, copy, drop {     // 定义消息结构体，具有 key、copy、drop 能力
        //TODO rename this to index            // 注释：待办事项：将 id 重命名为 index
        id: u64,                             // 消息 ID
        channel_id: ObjectID,                // 通道 ID
        sender: address,                     // 发送者地址
        content: String,                     // 消息内容
        timestamp: u64,                      // 时间戳
        message_type: u8,                    // 消息类型
        /// The addresses mentioned in the message  // 注释：消息中提到的地址
        mentions: vector<address>,           // 提及的地址列表
    }

    //TODO remove this after https://github.com/rooch-network/rooch/issues/3362  // 注释：待办事项：在问题 #3362 解决后移除
    struct MessageForAgent has copy, drop {  // 定义代理用消息结构体，具有 copy、drop 能力
        id: u64,                             // 消息 ID
        // Convert ObjectID to String         // 注释：将 ObjectID 转换为字符串
        channel_id: String,                  // 通道 ID（字符串形式）
        sender: address,                     // 发送者地址
        content: String,                     // 消息内容
        timestamp: u64,                      // 时间戳
        message_type: u8,                    // 消息类型
        /// The addresses mentioned in the message  // 注释：消息中提到的地址
        mentions: vector<address>,           // 提及的地址列表
    }

    struct MessageForAgentV2 has copy, drop, store {  // 定义代理用消息结构体 V2，具有 copy、drop、store 能力
        index: u64,                          // 消息索引
        sender: address,                     // 发送者地址
        content: String,                     // 消息内容
        timestamp: u64,                      // 时间戳
        message_type: u8,                    // 消息类型
    }

    /// Message Input Description            // 注释：消息输入描述
    const MESSAGE_INPUT_DESCRIPTION: vector<u8> = b"Message Input structure: A MessageInput contains a history of previous messages and the current message to process. | Message fields: | - index: message sequence number | - sender: sender's address | - content: message text | - timestamp: creation time in milliseconds | - message_type: 0=normal message, 2=action event message | Use message history to maintain conversation context and respond appropriately to the current message.";  // 定义常量：消息输入结构描述

    struct MessageInput has copy, drop {     // 定义消息输入结构体，具有 copy、drop 能力
        history: vector<MessageForAgent>,    // 历史消息列表
        current: MessageForAgent,            // 当前消息
    }

    struct MessageInputV2 has copy, drop {   // 定义消息输入结构体 V2，具有 copy、drop 能力
        history: vector<MessageForAgentV2>,  // 历史消息列表
        current: MessageForAgentV2,          // 当前消息
    }

    struct MessageInputV3 has copy, drop, store {  // 定义消息输入结构体 V3，具有 copy、drop、store 能力
        history: vector<MessageForAgentV2>,  // 历史消息列表
        channel_id: ObjectID,                // 通道 ID
        current: MessageForAgentV2,          // 当前消息
    }

    /// Constructor - message belongs to the sender  // 注释：构造函数 - 消息属于发送者
    public(friend) fun new_message_object(   // 定义友元函数：创建新消息对象
        id: u64,                             // 消息 ID
        channel_id: ObjectID,                // 通道 ID
        sender: address,                     // 发送者地址
        content: String,                     // 消息内容
        message_type: u8,                    // 消息类型
        mentions: vector<address>            // 提及的地址
    ): ObjectID {                            // 返回对象 ID
        let message = new_message(id, channel_id, sender, content, message_type, mentions);  // 创建消息
        let msg_obj = object::new(message);  // 将消息封装为对象
        let msg_id = object::id(&msg_obj);   // 获取对象 ID
        object::transfer_extend(msg_obj, sender);  // 将对象转移给发送者
        msg_id                               // 返回对象 ID
    }

    fun new_message(                         // 定义函数：创建新消息
        id: u64,                             // 消息 ID
        channel_id: ObjectID,                // 通道 ID
        sender: address,                     // 发送者地址
        content: String,                     // 消息内容
        message_type: u8,                    // 消息类型
        mentions: vector<address>            // 提及的地址
    ): Message {                             // 返回 Message 类型
        Message {                            // 创建并返回 Message 实例
            id,                              // ID
            channel_id,                      // 通道 ID
            sender,                          // 发送者
            content,                         // 内容
            timestamp: timestamp::now_milliseconds(),  // 当前时间戳
            message_type,                    // 消息类型
            mentions,                        // 提及的地址
        }
    }

    public fun new_direct_message_input(messages: vector<Message>): AgentInput<MessageInputV2> {  // 定义公开函数：创建直接消息输入
        let messages_for_agent = vector::empty();  // 初始化空的代理用消息向量
        vector::for_each(messages, |msg| {   // 遍历消息列表
            let msg: Message = msg;          // 将消息转换为 Message 类型
            vector::push_back(&mut messages_for_agent, MessageForAgentV2 {  // 添加代理用消息
                index: msg.id,               // 索引
                sender: msg.sender,          // 发送者
                content: msg.content,        // 内容
                timestamp: msg.timestamp,    // 时间戳
                message_type: msg.message_type,  // 消息类型
            });
        });
        let current = vector::pop_back(&mut messages_for_agent);  // 弹出最后一条消息作为当前消息
        let from = current.sender;           // 获取发送者地址
        let description = string::utf8(b"Receive a direct message from a user(");  // 初始化描述
        string::append(&mut description, address_utils::address_to_string(from));  // 添加发送者地址
        string::append(&mut description, string::utf8(b")\n"));  // 添加换行符
        string::append(&mut description, string::utf8(MESSAGE_INPUT_DESCRIPTION));  // 添加消息输入描述
        agent_input::new_agent_input(        // 创建并返回代理输入
            from,                            // 发送者
            description,                     // 描述
            MessageInputV2 {                 // 消息输入 V2
                history: messages_for_agent, // 历史消息
                current,                     // 当前消息
            }
        )
    }

    public fun new_channel_message_input(messages: vector<Message>): AgentInput<MessageInputV2> {  // 定义公开函数：创建通道消息输入
        let channel_id = vector::borrow(&messages, 0).channel_id;  // 获取第一条消息的通道 ID
        let messages_for_agent = vector::empty();  // 初始化空的代理用消息向量
        vector::for_each(messages, |msg| {   // 遍历消息列表
            let msg: Message = msg;          // 将消息转换为 Message 类型
            vector::push_back(&mut messages_for_agent, MessageForAgentV2 {  // 添加代理用消息
                index: msg.id,               // 索引
                sender: msg.sender,          // 发送者
                content: msg.content,        // 内容
                timestamp: msg.timestamp,    // 时间戳
                message_type: msg.message_type,  // 消息类型
            });
        });
        let current = vector::pop_back(&mut messages_for_agent);  // 弹出最后一条消息作为当前消息
        let description = string::utf8(b"Receive a message from a channel(");  // 初始化描述
        string::append(&mut description, channel_id_to_string(channel_id));  // 添加通道 ID
        string::append(&mut description, string::utf8(b")\n"));  // 添加换行符
        string::append(&mut description, string::utf8(MESSAGE_INPUT_DESCRIPTION));  // 添加消息输入描述
        agent_input::new_agent_input(        // 创建并返回代理输入
            current.sender,                  // 发送者
            description,                     // 描述
            MessageInputV2 {                 // 消息输入 V2
                history: messages_for_agent, // 历史消息
                current,                     // 当前消息
            }
        )
    }

    public fun new_agent_input(_messages: vector<Message>): AgentInput<MessageInput> {  // 定义公开函数：创建代理输入（已废弃）
        abort 0                              // 中止并抛出错误（无具体错误码）
    }

    public fun new_agent_input_v3(messages: vector<Message>, _is_direct_channel: bool): AgentInput<MessageInputV3> {  // 定义公开函数：创建代理输入 V3
        let channel_id = vector::borrow(&messages, 0).channel_id;  // 获取第一条消息的通道 ID
        let messages_for_agent = vector::empty();  // 初始化空的代理用消息向量
        vector::for_each(messages, |msg| {   // 遍历消息列表
            let msg: Message = msg;          // 将消息转换为 Message 类型
            vector::push_back(&mut messages_for_agent, MessageForAgentV2 {  // 添加代理用消息
                index: msg.id,               // 索引
                sender: msg.sender,          // 发送者
                content: msg.content,        // 内容
                timestamp: msg.timestamp,    // 时间戳
                message_type: msg.message_type,  // 消息类型
            });
        });
        let current = vector::pop_back(&mut messages_for_agent);  // 弹出最后一条消息作为当前消息
        let description = string::utf8(b"Receive a message from a channel(");  // 初始化描述
        string::append(&mut description, channel_id_to_string(channel_id));  // 添加通道 ID
        string::append(&mut description, string::utf8(b")\n"));  // 添加换行符
        string::append(&mut description, string::utf8(MESSAGE_INPUT_DESCRIPTION));  // 添加消息输入描述
        agent_input::new_agent_input(        // 创建并返回代理输入
            current.sender,                  // 发送者
            description,                     // 描述
            MessageInputV3 {                 // 消息输入 V3
                history: messages_for_agent, // 历史消息
                channel_id,                  // 通道 ID
                current,                     // 当前消息
            }
        )
    }

    // Getters                              // 注释：获取函数
    public fun get_id(message: &Message): u64 {  // 定义公开函数：获取消息 ID
        message.id                           // 返回消息 ID
    }

    public fun get_channel_id(message: &Message): ObjectID {  // 定义公开函数：获取通道 ID
        message.channel_id                   // 返回通道 ID
    }

    public fun get_content(message: &Message): String {  // 定义公开函数：获取消息内容
        message.content                      // 返回消息内容
    }

    public fun get_type(message: &Message): u8 {  // 定义公开函数：获取消息类型
        message.message_type                 // 返回消息类型
    }

    public fun get_timestamp(message: &Message): u64 {  // 定义公开函数：获取时间戳
        message.timestamp                    // 返回时间戳
    }

    public fun get_sender(message: &Message): address {  // 定义公开函数：获取发送者
        message.sender                       // 返回发送者地址
    }

    public fun get_mentions(message: &Message): &vector<address> {  // 定义公开函数：获取提及的地址
        &message.mentions                    // 返回提及地址列表的引用
    }

    // Constants                            // 注释：常量
    public fun type_user(): u8 { abort 0 }   // 定义公开函数：获取用户类型（未实现）
    public fun type_ai(): u8 { abort 0 }     // 定义公开函数：获取 AI 类型（未实现）

    public fun get_channel_id_from_input(input: &MessageInputV3): ObjectID {  // 定义公开函数：从输入获取通道 ID
        input.channel_id                     // 返回通道 ID
    }

    // =============== Tests helper functions ===============  // 注释：测试辅助函数
    
    #[test_only]
    public fun new_message_for_test(         // 定义仅测试函数：为测试创建消息
        id: u64,                             // 消息 ID
        channel_id: ObjectID,                // 通道 ID
        sender: address,                     // 发送者地址
        content: String,                     // 消息内容
        message_type: u8,                    // 消息类型
        mentions: vector<address>            // 提及的地址
    ): Message {                             // 返回 Message 类型
        new_message(id, channel_id, sender, content, message_type, mentions)  // 调用 new_message 创建消息
    }

    #[test]
    fun test_message_creation() {            // 定义测试函数：测试消息创建
        //TODO provide a test function to generate ObjectID in object.move  // 注释：待办事项：在 object.move 中提供生成 ObjectID 的测试函数
        let test_channel_id = object::named_object_id<Message>();  // 使用命名对象 ID 作为测试通道 ID
        let mentions = vector::empty();      // 初始化空的提及地址向量
        vector::push_back(&mut mentions, @0x43);  // 添加一个提及地址
        let msg_id = new_message_object(     // 创建消息对象并获取 ID
            1,                               // 消息 ID
            test_channel_id,                 // 通道 ID
            @0x42,                           // 发送者地址
            string::utf8(b"test content"),   // 消息内容
            type_normal(),                   // 消息类型：普通消息
            mentions                         // 提及地址
        );
        let msg_obj = object::borrow_object<Message>(msg_id);  // 借用消息对象
        let msg = object::borrow(msg_obj);   // 借用消息引用
        
        assert!(get_id(msg) == 1, 0);        // 断言：ID 正确
        assert!(get_channel_id(msg) == test_channel_id, 1);  // 断言：通道 ID 正确
        assert!(get_content(msg) == string::utf8(b"test content"), 2);  // 断言：内容正确
        assert!(get_type(msg) == type_normal(), 3);  // 断言：类型正确
        assert!(get_sender(msg) == @0x42, 4);  // 断言：发送者正确
        assert!(object::owner(msg_obj) == @0x42, 5);  // 断言：拥有者正确
    }
}