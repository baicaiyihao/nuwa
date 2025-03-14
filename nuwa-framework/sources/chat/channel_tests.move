#[test_only]
module nuwa_framework::channel_tests {       // 定义仅测试模块：通道测试
    use std::string;                         // 导入标准库中的字符串模块
    use std::signer;                         // 导入标准库中的签名者模块
    use std::vector;                         // 导入标准库中的向量模块
    use moveos_std::account;                 // 导入 MoveOS 标准库中的账户模块
    use moveos_std::timestamp;               // 导入 MoveOS 标准库中的时间戳模块
    use moveos_std::object;                  // 导入 MoveOS 标准库中的对象模块
    use nuwa_framework::channel;             // 导入 nuwa_framework 中的通道模块
    use nuwa_framework::message;             // 导入 nuwa_framework 中的消息模块
    use nuwa_framework::agent;               // 导入 nuwa_framework 中的代理模块

    // Test helpers                         // 注释：测试辅助函数
    #[test_only]
    fun create_account_with_address(addr: address): signer {  // 定义仅测试函数：根据地址创建账户签名者
        account::create_signer_for_testing(addr)  // 创建并返回用于测试的签名者
    }

    #[test]
    fun test_create_ai_home_channel() {      // 定义测试函数：测试创建 AI 主通道
        nuwa_framework::character_registry::init_for_test();  // 为测试初始化角色注册表
        let (agent, cap) = agent::create_test_agent();  // 创建测试代理和代理能力对象
        let ai_account = agent::get_agent_address(agent);  // 获取代理地址
        timestamp::update_global_time_for_test(1000);  // 更新全局时间为 1000 毫秒

        let channel_id = channel::create_ai_home_channel(agent);  // 创建 AI 主通道并获取 ID
        let channel = object::borrow_object(channel_id);  // 借用通道对象
        
        // Verify AI is a member             // 注释：验证 AI 是成员
        assert!(channel::is_member(channel, ai_account), 0);  // 断言：AI 是通道成员
        
        // Try joining as a user             // 注释：尝试以用户身份加入
        let user = create_account_with_address(@0x43);  // 创建测试用户
        let channel = object::borrow_mut_object_shared(channel_id);  // 借用共享的可变通道对象
        channel::join_channel(&user, channel);  // 用户加入通道
        
        // Verify user is now a member       // 注释：验证用户现在是成员
        let channel = object::borrow_object(channel_id);  // 借用通道对象
        assert!(channel::is_member(channel, signer::address_of(&user)), 1);  // 断言：用户是通道成员

        channel::delete_channel_for_testing(channel_id);  // 删除测试通道
        agent::destroy_agent_cap(cap);       // 销毁代理能力对象
    }

    #[test]
    fun test_create_ai_peer_channel() {      // 定义测试函数：测试创建 AI-用户通道
        nuwa_framework::character_registry::init_for_test();  // 为测试初始化角色注册表
        let user = create_account_with_address(@0x42);  // 创建测试用户
        // Create a test agent instead of just using an address  // 注释：创建测试代理而不仅仅使用地址
        let (agent, cap) = agent::create_test_agent();  // 创建测试代理和代理能力对象
        let ai_address = agent::get_agent_address(agent);  // 获取代理地址
        timestamp::update_global_time_for_test(1000);  // 更新全局时间为 1000 毫秒

        let channel_id = channel::create_ai_peer_channel(&user, agent);  // 创建 AI-用户通道并获取 ID
        let channel = object::borrow_object(channel_id);  // 借用通道对象
        
        // Verify both user and AI are members  // 注释：验证用户和 AI 都是成员
        assert!(channel::is_member(channel, signer::address_of(&user)), 0);  // 断言：用户是成员
        assert!(channel::is_member(channel, ai_address), 1);  // 断言：AI 是成员

        channel::delete_channel_for_testing(channel_id);  // 删除测试通道
        agent::destroy_agent_cap(cap);       // 销毁代理能力对象
    }

    #[test]
    fun test_message_sending() {             // 定义测试函数：测试消息发送
        nuwa_framework::character_registry::init_for_test();  // 为测试初始化角色注册表
        let user = create_account_with_address(@0x42);  // 创建测试用户
        // Create a test agent               // 注释：创建测试代理
        let (agent, cap) = agent::create_test_agent();  // 创建测试代理和代理能力对象
         
        // Create peer channel               // 注释：创建对等通道
        let channel_id = channel::create_ai_peer_channel(  // 创建 AI-用户通道
            &user,
            agent
        );
        
        // Send message                      // 注释：发送消息
        let channel = object::borrow_mut_object_shared(channel_id);  // 借用共享的可变通道对象
        let msg_content = string::utf8(b"Hello AI!");  // 定义消息内容
        let mentions = vector::empty();      // 初始化空提及列表
        channel::send_message(&user, channel, msg_content, mentions);  // 发送消息
        
        // Verify message                    // 注释：验证消息
        let channel = object::borrow_object(channel_id);  // 借用通道对象
        let messages = channel::get_messages(channel);  // 获取所有消息
        assert!(vector::length(&messages) == 1, 0);  // 断言：消息数量为 1
        
        let msg = vector::borrow(&messages, 0);  // 借用第一条消息
        assert!(message::get_content(msg) == msg_content, 1);  // 断言：消息内容正确
        assert!(message::get_sender(msg) == signer::address_of(&user), 2);  // 断言：发送者正确
        assert!(message::get_type(msg) == message::type_normal(), 3);  // 断言：消息类型为普通消息

        channel::delete_channel_for_testing(channel_id);  // 删除测试通道
        agent::destroy_agent_cap(cap);       // 销毁代理能力对象
    }

    #[test]
    #[expected_failure(abort_code = channel::ErrorNotMember)]  // 标记预期失败：非成员错误
    fun test_unauthorized_message() {        // 定义测试函数：测试未授权消息
        nuwa_framework::character_registry::init_for_test();  // 为测试初始化角色注册表
        let user1 = create_account_with_address(@0x42);  // 创建测试用户 1
        let user2 = create_account_with_address(@0x44);  // 创建测试用户 2
        // Create a test agent               // 注释：创建测试代理
        let (agent, cap) = agent::create_test_agent();  // 创建测试代理和代理能力对象
        
        let channel_id = channel::create_ai_peer_channel(  // 创建 AI-用户通道（用户 1）
            &user1,
            agent
        );
        
        // Try sending message from unauthorized user  // 注释：尝试从未授权用户发送消息
        let channel = object::borrow_mut_object_shared(channel_id);  // 借用共享的可变通道对象
        
        let mentions = vector::empty();      // 初始化空提及列表
        channel::send_message(&user2, channel, string::utf8(b"Unauthorized message"), mentions);  // 用户 2 发送消息（预期失败）

        channel::delete_channel_for_testing(channel_id);  // 删除测试通道
        agent::destroy_agent_cap(cap);       // 销毁代理能力对象
    }

    #[test]
    fun test_message_pagination() {          // 定义测试函数：测试消息分页
        nuwa_framework::character_registry::init_for_test();  // 为测试初始化角色注册表
        let user = create_account_with_address(@0x42);  // 创建测试用户
        // Create a test agent               // 注释：创建测试代理
        let (agent, cap) = agent::create_test_agent();  // 创建测试代理和代理能力对象
         
        let channel_id = channel::create_ai_peer_channel(  // 创建 AI-用户通道
            &user,
            agent
        );
        
        // Send multiple messages            // 注释：发送多条消息
        let channel = object::borrow_mut_object_shared(channel_id);  // 借用共享的可变通道对象
        let i = 0;                           // 初始化索引
        let mentions = vector::empty();      // 初始化空提及列表
        while (i < 5) {                      // 发送 5 条消息
            channel::send_message(&user, channel, string::utf8(b"Message"), mentions);  // 发送消息
            i = i + 1;                       // 索引递增
        };
        
        // Test pagination                   // 注释：测试分页
        let channel = object::borrow_object(channel_id);  // 借用通道对象
        let messages = channel::get_messages_paginated(channel, 1, 2);  // 获取第 1 条开始的 2 条消息
        assert!(vector::length(&messages) == 2, 0);  // 断言：返回 2 条消息
        
        // Test last messages                // 注释：测试最后消息
        let messages = channel::get_last_messages(channel, 3);  // 获取最后 3 条消息
        assert!(vector::length(&messages) == 3, 1);  // 断言：返回 3 条消息

        channel::delete_channel_for_testing(channel_id);  // 删除测试通道
        agent::destroy_agent_cap(cap);       // 销毁代理能力对象
    }

    #[test]
    fun test_member_info() {                 // 定义测试函数：测试成员信息
        nuwa_framework::character_registry::init_for_test();  // 为测试初始化角色注册表
        let user = create_account_with_address(@0x42);  // 创建测试用户
        // Create a test agent               // 注释：创建测试代理
        let (agent, cap) = agent::create_test_agent();  // 创建测试代理和代理能力对象
        timestamp::update_global_time_for_test(1000);  // 更新全局时间为 1000 毫秒
        
        let channel_id = channel::create_ai_peer_channel(  // 创建 AI-用户通道
            &user,
            agent
        );
        
        let channel = object::borrow_object(channel_id);  // 借用通道对象
        let (joined_at, last_active) = channel::get_member_info(channel, signer::address_of(&user));  // 获取成员信息
        assert!(joined_at == 1000, 0);       // 断言：加入时间为 1000
        assert!(last_active == 1000, 1);     // 断言：最后活跃时间为 1000

        channel::delete_channel_for_testing(channel_id);  // 删除测试通道
        agent::destroy_agent_cap(cap);       // 销毁代理能力对象
    }
}