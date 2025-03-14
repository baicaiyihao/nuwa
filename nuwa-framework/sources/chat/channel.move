module nuwa_framework::channel {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::vector;                         // 导入标准库中的向量模块
    use std::bcs;                            // 导入标准库中的 BCS（二进制序列化）模块
    use std::hash;                           // 导入标准库中的哈希模块
    use std::option::{Self, Option};         // 导入标准库中的选项模块，并引入 Option 类型
    use moveos_std::address;                 // 导入 MoveOS 标准库中的地址模块
    use moveos_std::table::{Self, Table};    // 导入 MoveOS 标准库中的表模块，并引入 Table 类型
    use moveos_std::object::{Self, Object, ObjectID};  // 导入 MoveOS 标准库中的对象模块，并引入 Object 和 ObjectID 类型
    use moveos_std::timestamp;               // 导入 MoveOS 标准库中的时间戳模块
    use moveos_std::signer;                  // 导入 MoveOS 标准库中的签名者模块
    use nuwa_framework::message::{Self, Message};  // 导入 nuwa_framework 中的消息模块，并引入 Message 类型
    use nuwa_framework::agent::{Self, Agent};  // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型

    friend nuwa_framework::response_action;  // 声明 response_action 模块为友元模块
    friend nuwa_framework::task_entry;       // 声明 task_entry 模块为友元模块

    // Error codes                           // 注释：错误码
    const ErrorChannelNotFound: u64 = 1;     // 定义错误码：通道未找到
    const ErrorChannelAlreadyExists: u64 = 2;  // 定义错误码：通道已存在
    const ErrorNotAuthorized: u64 = 3;       // 定义错误码：未授权
    const ErrorChannelInactive: u64 = 4;     // 定义错误码：通道未激活
    const ErrorMaxMembersReached: u64 = 5;   // 定义错误码：达到最大成员数
    const ErrorInvalidChannelName: u64 = 6;  // 定义错误码：无效通道名称
    const ErrorInvalidChannelType: u64 = 7;  // 定义错误码：无效通道类型
    const ErrorNotMember: u64 = 8;           // 定义错误码：不是成员
    const ErrorDeprecatedFunction: u64 = 9;  // 定义错误码：已废弃的函数
    const ErrorMentionedUserNotMember: u64 = 10;  // 定义错误码：提及的用户不是成员

    /// Channel status constants             // 注释：通道状态常量
    const CHANNEL_STATUS_ACTIVE: u8 = 0;     // 定义常量：通道激活状态
    const CHANNEL_STATUS_CLOSED: u8 = 1;     // 定义常量：通道关闭状态
    const CHANNEL_STATUS_BANNED: u8 = 2;     // 定义常量：通道被禁状态

    // Channel type constants with built-in visibility  // 注释：通道类型常量，包含内置可见性
    const CHANNEL_TYPE_AI_HOME: u8 = 0;      // 定义常量：AI 主通道类型，始终公开
    const CHANNEL_TYPE_AI_PEER: u8 = 1;      // 定义常量：AI-用户一对一通道类型，始终私有

    // Public functions to expose channel types  // 注释：公开函数以暴露通道类型
    public fun channel_type_ai_home(): u8 { CHANNEL_TYPE_AI_HOME }  // 定义公开函数：返回 AI 主通道类型
    public fun channel_type_ai_peer(): u8 { CHANNEL_TYPE_AI_PEER }  // 定义公开函数：返回 AI-用户通道类型

    /// Member structure to store member information  // 注释：成员结构，用于存储成员信息
    struct Member has store, drop {          // 定义成员结构体，具有 store 和 drop 能力
        address: address,                    // 成员地址
        joined_at: u64,                      // 加入时间（毫秒）
        last_active: u64,                    // 最后活跃时间（毫秒）
    }

    /// Channel structure for chat functionality  // 注释：通道结构，用于聊天功能
    /// Note on privacy:                     // 注释：关于隐私的说明
    /// - All messages in the channel are visible on-chain, regardless of channel privacy settings  // 注释：通道中的所有消息在链上可见，无论隐私设置如何
    /// - is_public: true  => Anyone can join the channel automatically when sending their first message  // 注释：is_public 为 true => 任何人发送第一条消息时可自动加入通道
    /// - is_public: false => Only admins can add members, and only members can send messages  // 注释：is_public 为 false => 只有管理员可添加成员，只有成员可发送消息
    struct Channel has key {                 // 定义通道结构体，具有 key 能力
        title: String,                       // 通道标题
        creator: address,                    // 创建者地址（AI_HOME 为 AI 地址，AI_PEER 为用户地址）
        members: Table<address, Member>,     // 成员表（键为地址，值为成员信息）
        messages: Table<u64, ObjectID>,      // 消息表（键为消息计数，值为消息对象 ID）
        message_counter: u64,                // 消息计数器
        created_at: u64,                     // 创建时间（毫秒）
        last_active: u64,                    // 最后活跃时间（毫秒）
        status: u8,                          // 通道状态
        channel_type: u8,                    // 通道类型（AI_HOME 或 AI_PEER）
    }

    /// Initialize a new AI home channel     // 注释：初始化新的 AI 主通道
    public fun create_ai_home_channel(       // 定义公开函数：创建 AI 主通道
        agent: &mut Object<Agent>,           // 可变的代理对象
    ): ObjectID {                            // 返回通道对象 ID
        let agent_address = agent::get_agent_address(agent);  // 获取代理地址
        let channel_id = object::account_named_object_id<Channel>(agent_address);  // 生成账户命名对象 ID
        assert!(!object::exists_object(channel_id), ErrorChannelAlreadyExists);  // 断言：确保通道不存在，否则抛出已存在错误
        
        let agent_username = *agent::get_agent_username(agent);  // 获取代理用户名
        let title = string::utf8(b"Home channel for ");  // 初始化标题
        string::append(&mut title, agent_username);  // 添加用户名到标题
        let creator = agent_address;         // 设置创建者为代理地址
        let now = timestamp::now_milliseconds();  // 获取当前时间戳
        
        let channel = Channel {              // 创建 Channel 实例
            title,                           // 标题
            creator,                         // 创建者
            members: table::new(),           // 初始化空的成员表
            messages: table::new(),          // 初始化空的消息表
            message_counter: 0,              // 消息计数器初始为 0
            created_at: now,                 // 创建时间
            last_active: now,                // 最后活跃时间
            status: CHANNEL_STATUS_ACTIVE,   // 状态：激活
            channel_type: CHANNEL_TYPE_AI_HOME,  // 类型：AI 主通道
        };

        // Add AI as member                  // 注释：将 AI 添加为成员
        add_member_internal(&mut channel, creator, now);  // 内部添加成员
        // Every AI can only have one AI_HOME channel  // 注释：每个 AI 只能有一个 AI 主通道
        let channel_obj = object::new_account_named_object(creator, channel);  // 创建账户命名对象
        let channel_id = object::id(&channel_obj);  // 获取对象 ID
        object::to_shared(channel_obj);      // 设置为共享对象
        channel_id                           // 返回通道 ID
    }

    public fun get_agent_home_channel_id(agent: &Object<Agent>): ObjectID {  // 定义公开函数：获取代理主通道 ID
        let agent_address = agent::get_agent_address(agent);  // 获取代理地址
        object::account_named_object_id<Channel>(agent_address)  // 返回账户命名对象 ID
    }

    public(friend) fun create_ai_peer_channel_internal(user_address: address, agent: &mut Object<Agent>): ObjectID {  // 定义友元函数：内部创建 AI-用户通道
        let agent_address = agent::get_agent_address(agent);  // 获取代理地址
        let creator = agent_address;         // 设置创建者为代理地址
        let title = string::utf8(b"Direct message with ");  // 初始化标题
        string::append(&mut title, *agent::get_agent_username(agent));  // 添加代理用户名
        let now = timestamp::now_milliseconds();  // 获取当前时间戳
        
        let channel = Channel {              // 创建 Channel 实例
            title,                           // 标题
            creator,                         // 创建者
            members: table::new(),           // 初始化空的成员表
            messages: table::new(),          // 初始化空的消息表
            message_counter: 0,              // 消息计数器初始为 0
            created_at: now,                 // 创建时间
            last_active: now,                // 最后活跃时间
            status: CHANNEL_STATUS_ACTIVE,   // 状态：激活
            channel_type: CHANNEL_TYPE_AI_PEER,  // 类型：AI-用户通道
        };

        // Add both user and AI as members   // 注释：将用户和 AI 添加为成员
        add_member_internal(&mut channel, creator, now);  // 添加代理为成员
        add_member_internal(&mut channel, user_address, now);  // 添加用户为成员
        let id = generate_peer_channel_id(agent_address, user_address);  // 生成通道 ID
        let channel_obj = object::new_with_id(id, channel);  // 使用自定义 ID 创建对象
        let channel_id = object::id(&channel_obj);  // 获取对象 ID
        object::to_shared(channel_obj);      // 设置为共享对象
        channel_id                           // 返回通道 ID
    }

    /// Initialize a new user to AI direct message channel  // 注释：初始化新的用户到 AI 直接消息通道
    public fun create_ai_peer_channel(       // 定义公开函数：创建 AI-用户通道
        user_account: &signer,               // 用户签名者
        agent: &mut Object<Agent>,           // 可变的代理对象
    ): ObjectID {                            // 返回通道对象 ID
        let user_address = signer::address_of(user_account);  // 获取用户地址
        create_ai_peer_channel_internal(user_address, agent)  // 调用内部函数创建通道
    }

    public entry fun create_ai_peer_channel_entry(  // 定义入口函数：创建 AI-用户通道
        user_account: &signer,               // 用户签名者
        agent: &mut Object<Agent>,           // 可变的代理对象
    ) {
        let _id = create_ai_peer_channel(user_account, agent);  // 创建通道并忽略返回值
    }

    public fun get_ai_peer_channel_id(agent: &Object<Agent>, user_address: address): Option<ObjectID> {  // 定义公开函数：获取 AI-用户通道 ID
        let id = generate_peer_channel_id(agent::get_agent_address(agent), user_address);  // 生成通道 ID
        let channel_obj_id = object::custom_object_id<address, Channel>(id);  // 生成自定义对象 ID
        if (object::exists_object(channel_obj_id)) {  // 如果对象存在
            option::some(channel_obj_id)     // 返回 Some(通道 ID)
        } else {
            option::none()                   // 返回 None
        }
    }

    fun generate_ai_peer_channel_id(agent: &Object<Agent>, user_address: address): ObjectID {  // 定义函数：生成 AI-用户通道 ID
        let id = generate_peer_channel_id(agent::get_agent_address(agent), user_address);  // 生成通道 ID
        object::custom_object_id<address, Channel>(id)  // 返回自定义对象 ID
    }

    //TODO remove this function               // 注释：待办事项：移除此函数
    public fun get_peer_channel_id(agent_address: address, user_address: address): ObjectID {  // 定义公开函数：获取对等通道 ID
        let id = generate_peer_channel_id(agent_address, user_address);  // 生成通道 ID
        object::custom_object_id<address, Channel>(id)  // 返回自定义对象 ID
    }

    fun generate_peer_channel_id(agent_address: address, user_address: address): address {  // 定义函数：生成对等通道 ID
        let bytes = vector::empty<u8>();     // 初始化空字节向量
        vector::append(&mut bytes, bcs::to_bytes(&agent_address));  // 添加代理地址的 BCS 序列化
        vector::append(&mut bytes, bcs::to_bytes(&user_address));  // 添加用户地址的 BCS 序列化
        let hash = hash::sha3_256(bytes);    // 对字节向量进行 SHA3-256 哈希
        address::from_bytes(hash)            // 从哈希生成地址并返回
    }

    /// Add message to channel - use message_counter as id  // 注释：向通道添加消息 - 使用消息计数器作为 ID
    fun add_message(channel_obj: &mut Object<Channel>, sender: address, content: String, message_type: u8, mentions: vector<address>) {  // 定义函数：添加消息
        let channel_id = object::id(channel_obj);  // 获取通道对象 ID
        let channel = object::borrow_mut(channel_obj);  // 借用可变的通道引用
        let msg_id = message::new_message_object(  // 创建消息对象并获取 ID
            channel.message_counter,         // 消息计数器作为 ID
            channel_id,                      // 通道 ID
            sender,                          // 发送者
            content,                         // 内容
            message_type,                    // 消息类型
            mentions                         // 提及的地址
        );
        table::add(&mut channel.messages, channel.message_counter, msg_id);  // 将消息 ID 添加到消息表
        channel.message_counter = channel.message_counter + 1;  // 增加消息计数器
    }

    /// Send a message and trigger AI response if needed  // 注释：发送消息并在需要时触发 AI 响应
    public fun send_message(                 // 定义公开函数：发送消息
        account: &signer,                    // 发送者签名者
        channel_obj: &mut Object<Channel>,   // 可变的通道对象
        content: String,                     // 消息内容
        mentions: vector<address>            // 提及的地址
    ) {
        vector::for_each(mentions, |addr| {  // 遍历提及的地址
            assert!(is_channel_member(channel_obj, addr), ErrorMentionedUserNotMember);  // 断言：确保提及的用户是成员
        });
        let sender = signer::address_of(account);  // 获取发送者地址
        let now = timestamp::now_milliseconds();  // 获取当前时间戳
        let channel = object::borrow_mut(channel_obj);  // 借用可变的通道引用

        // Check if sender is a member        // 注释：检查发送者是否为成员
        assert!(table::contains(&channel.members, sender), ErrorNotMember);  // 断言：确保发送者是成员
        assert!(channel.status == CHANNEL_STATUS_ACTIVE, ErrorChannelInactive);  // 断言：确保通道激活
        
        // Update member's last active time  // 注释：更新成员的最后活跃时间
        let member = table::borrow_mut(&mut channel.members, sender);  // 借用可变的成员引用
        member.last_active = now;            // 更新最后活跃时间
        channel.last_active = now;           // 更新通道最后活跃时间

        add_message(channel_obj, sender, content, message::type_normal(), mentions);  // 添加普通消息
    }

    /// Add AI response to the channel       // 注释：向通道添加 AI 响应
    public(friend) fun add_ai_response(      // 定义友元函数：添加 AI 响应
        channel_obj: &mut Object<Channel>,   // 可变的通道对象
        response_message: String,            // 响应消息内容
        ai_agent_address: address            // AI 代理地址
    ) {
        add_message(channel_obj, ai_agent_address, response_message, message::type_normal(), vector::empty());  // 添加普通消息，无提及
    }

    public(friend) fun add_ai_event(         // 定义友元函数：添加 AI 事件
        channel_obj: &mut Object<Channel>,   // 可变的通道对象
        event: String,                       // 事件内容
        ai_agent_address: address            // AI 代理地址
    ) {
        add_message(channel_obj, ai_agent_address, event, message::type_action_event(), vector::empty());  // 添加动作事件消息，无提及
    }

    public(friend) fun send_ai_direct_message(  // 定义友元函数：发送 AI 直接消息
        agent: &mut Object<Agent>,           // 可变的代理对象
        user_address: address,               // 用户地址
        content: String,                     // 消息内容
    ): ObjectID {                            // 返回通道对象 ID
        let channel_id = generate_ai_peer_channel_id(agent, user_address);  // 生成 AI-用户通道 ID
        if (!object::exists_object(channel_id)) {  // 如果通道不存在
            create_ai_peer_channel_internal(user_address, agent);  // 创建通道
        };
        let channel_obj = object::borrow_mut_object_shared<Channel>(channel_id);  // 借用共享的可变通道对象
        add_message(channel_obj, agent::get_agent_address(agent), content, message::type_normal(), vector::empty());  // 添加普通消息
        channel_id                           // 返回通道 ID
    }

    /// Get all messages in the channel      // 注释：获取通道中的所有消息
    public fun get_messages(channel: &Object<Channel>): vector<Message> {  // 定义公开函数：获取所有消息
        let channel_ref = object::borrow(channel);  // 借用通道引用
        let messages = vector::empty<Message>();  // 初始化空的消息向量
        let i = 0;                           // 初始化索引
        while (i < channel_ref.message_counter) {  // 遍历消息计数器
            let msg_id = table::borrow(&channel_ref.messages, i);  // 借用消息 ID
            let msg_obj = object::borrow_object<Message>(*msg_id);  // 借用消息对象
            vector::push_back(&mut messages, *object::borrow(msg_obj));  // 添加消息到向量
            i = i + 1;                       // 索引递增
        };
        messages                             // 返回消息列表
    }

    /// Get messages with pagination         // 注释：分页获取消息
    public fun get_messages_paginated(       // 定义公开函数：分页获取消息
        channel: &Object<Channel>,           // 通道对象
        start_index: u64,                    // 开始索引
        limit: u64                           // 限制数量
    ): vector<Message> {                     // 返回消息向量
        let channel_ref = object::borrow(channel);  // 借用通道引用
        let messages = vector::empty<Message>();  // 初始化空的消息向量
        
        // Check if start_index is valid      // 注释：检查开始索引是否有效
        if (start_index >= channel_ref.message_counter) {  // 如果开始索引超出消息计数
            return messages                  // 返回空列表
        };
        
        // Calculate end index               // 注释：计算结束索引
        let end_index = if (start_index + limit > channel_ref.message_counter) {  // 如果超出消息总数
            channel_ref.message_counter      // 使用消息总数
        } else {
            start_index + limit              // 使用开始索引加限制
        };
        
        let i = start_index;                 // 从开始索引开始
        while (i < end_index) {              // 遍历到结束索引
            let msg_id = table::borrow(&channel_ref.messages, i);  // 借用消息 ID
            let msg_obj = object::borrow_object<Message>(*msg_id);  // 借用消息对象
            vector::push_back(&mut messages, *object::borrow(msg_obj));  // 添加消息到向量
            i = i + 1;                       // 索引递增
        };
        messages                             // 返回消息列表
    }

    /// Get total message count in the channel  // 注释：获取通道中的消息总数
    public fun get_message_count(channel: &Object<Channel>): u64 {  // 定义公开函数：获取消息总数
        let channel_ref = object::borrow(channel);  // 借用通道引用
        channel_ref.message_counter          // 返回消息计数器
    }

    /// Get last N messages from the channel  // 注释：获取通道中最后 N 条消息
    public fun get_last_messages(channel_obj: &Object<Channel>, limit: u64): vector<Message> {  // 定义公开函数：获取最后消息
        let channel = object::borrow(channel_obj);  // 借用通道引用
        let messages = vector::empty();      // 初始化空的消息向量
        let start = if (channel.message_counter > limit) {  // 如果消息总数大于限制
            channel.message_counter - limit  // 计算开始索引
        } else {
            0                                // 从头开始
        };
        
        let i = start;                       // 从开始索引开始
        while (i < channel.message_counter) {  // 遍历到消息总数
            let msg_id = table::borrow(&channel.messages, i);  // 借用消息 ID
            let msg_obj = object::borrow_object<Message>(*msg_id);  // 借用消息对象
            vector::push_back(&mut messages, *object::borrow(msg_obj));  // 添加消息到向量
            i = i + 1;                       // 索引递增
        };
        messages                             // 返回消息列表
    }

    /// Check if address is member of channel  // 注释：检查地址是否为通道成员
    public fun is_member(channel: &Object<Channel>, addr: address): bool {  // 定义公开函数：检查是否为成员
        let channel_ref = object::borrow(channel);  // 借用通道引用
        table::contains(&channel_ref.members, addr)  // 返回是否包含该地址
    }

    /// Get member info                     // 注释：获取成员信息
    public fun get_member_info(channel: &Object<Channel>, addr: address): (u64, u64) {  // 定义公开函数：获取成员信息
        let channel_ref = object::borrow(channel);  // 借用通道引用
        assert!(table::contains(&channel_ref.members, addr), ErrorNotAuthorized);  // 断言：确保是成员
        let member = table::borrow(&channel_ref.members, addr);  // 借用成员引用
        (
            member.joined_at,                // 返回加入时间
            member.last_active               // 返回最后活跃时间
        )
    }

    //TODO remove this function              // 注释：待办事项：移除此函数
    /// Send a message and trigger AI response if needed  // 注释：发送消息并在需要时触发 AI 响应
    public entry fun send_message_entry(     // 定义入口函数：发送消息（已废弃）
        _caller: &signer,                    // 调用者签名者
        _channel_obj: &mut Object<Channel>,  // 可变的通道对象
        _content: String,                    // 消息内容
        _mentions: vector<address>           // 提及的地址
    ) {
        abort ErrorDeprecatedFunction        // 中止并抛出已废弃错误
    }

    /// Update channel title                // 注释：更新通道标题
    public(friend) fun update_channel_title(channel_obj: &mut Channel, new_title: String) {  // 定义友元函数：更新通道标题
        channel_obj.title = new_title;       // 更新标题
    }

    /// Add member to channel               // 注释：向通道添加成员
    fun add_member_internal(                 // 定义函数：内部添加成员
        channel: &mut Channel,               // 可变的通道引用
        member_addr: address,                // 成员地址
        now: u64,                            // 当前时间
    ) {
        if (!table::contains(&channel.members, member_addr)) {  // 如果成员不存在
            let member = Member {            // 创建 Member 实例
                address: member_addr,        // 地址
                joined_at: now,              // 加入时间
                last_active: now,            // 最后活跃时间
            };
            table::add(&mut channel.members, member_addr, member);  // 添加到成员表
        }
    }

    /// Join channel for AI_HOME type       // 注释：加入 AI 主通道
    public fun join_channel(                 // 定义公开函数：加入通道
        account: &signer,                    // 签名者
        channel_obj: &mut Object<Channel>,   // 可变的通道对象
    ) {
        let sender = signer::address_of(account);  // 获取发送者地址
        let channel = object::borrow_mut(channel_obj);  // 借用可变的通道引用
        
        // Only AI_HOME channels can be joined directly  // 注释：只有 AI 主通道可直接加入
        assert!(channel.channel_type == CHANNEL_TYPE_AI_HOME, ErrorNotAuthorized);  // 断言：确保是 AI 主通道
        
        let now = timestamp::now_milliseconds();  // 获取当前时间戳
        add_member_internal(channel, sender, now);  // 内部添加成员
    }

    /// Entry function for joining a channel  // 注释：加入通道的入口函数
    public entry fun join_channel_entry(     // 定义入口函数：加入通道
        account: &signer,                    // 签名者
        channel_obj: &mut Object<Channel>,   // 可变的通道对象
    ) {
        join_channel(account, channel_obj);  // 调用加入通道函数
    }

    // ==================== Getters ====================  // 注释：获取函数

    public fun get_channel_title(channel: &Object<Channel>): &String {  // 定义公开函数：获取通道标题
        let channel_ref = object::borrow(channel);  // 借用通道引用
        &channel_ref.title                   // 返回标题的引用
    }

    public fun get_channel_creator(channel: &Object<Channel>): address {  // 定义公开函数：获取通道创建者
        let channel_ref = object::borrow(channel);  // 借用通道引用
        channel_ref.creator                  // 返回创建者地址
    }

    public fun get_channel_created_at(channel: &Object<Channel>): u64 {  // 定义公开函数：获取通道创建时间
        let channel_ref = object::borrow(channel);  // 借用通道引用
        channel_ref.created_at               // 返回创建时间
    }

    public fun get_channel_last_active(channel: &Object<Channel>): u64 {  // 定义公开函数：获取通道最后活跃时间
        let channel_ref = object::borrow(channel);  // 借用通道引用
        channel_ref.last_active              // 返回最后活跃时间
    }

    public fun get_channel_status(channel: &Object<Channel>): u8 {  // 定义公开函数：获取通道状态
        let channel_ref = object::borrow(channel);  // 借用通道引用
        channel_ref.status                   // 返回状态
    }

    public fun get_channel_type(channel: &Object<Channel>): u8 {  // 定义公开函数：获取通道类型
        let channel_ref = object::borrow(channel);  // 借用通道引用
        channel_ref.channel_type             // 返回类型
    }

    public fun is_channel_member(channel: &Object<Channel>, addr: address): bool {  // 定义公开函数：检查是否为通道成员
        let channel_ref = object::borrow(channel);  // 借用通道引用
        table::contains(&channel_ref.members, addr)  // 返回是否为成员
    }

    // =================== Test helpers ===================  // 注释：测试辅助函数

    #[test_only]
    /// Test helper function to delete a channel, only available in test mode  // 注释：测试辅助函数，用于删除通道，仅在测试模式下可用
    fun force_delete_channel(channel: Object<Channel>) {  // 定义仅测试函数：强制删除通道
        let Channel {                        // 解构 Channel 对象
            title: _,
            creator: _,
            members,                         // 成员表
            messages,                        // 消息表
            message_counter: _,
            created_at: _,
            last_active: _,
            status: _,
            channel_type: _,
        } = object::remove(channel);         // 移除通道对象
        
        table::drop(members);                // 删除成员表
        table::drop(messages);               // 删除消息表
    }

    #[test_only]
    /// Public test helper function to delete a channel  // 注释：公开测试辅助函数，用于删除通道
    public fun delete_channel_for_testing(channel_id: ObjectID) {  // 定义仅测试函数：为测试删除通道
        let channel = object::take_object_extend<Channel>(channel_id);  // 取出通道对象
        force_delete_channel(channel);       // 调用强制删除函数
    }
}