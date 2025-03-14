module nuwa_framework::channel_entry {
    use std::vector;                         // 导入标准库中的向量模块
    use std::string::String;                 // 导入标准库中的字符串模块，并引入 String 类型
    use moveos_std::object::Object;          // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use moveos_std::type_info;               // 导入 MoveOS 标准库中的类型信息模块
    use rooch_framework::coin::{Self, Coin};  // 导入 Rooch 框架中的代币模块，并引入 Coin 类型
    use rooch_framework::gas_coin::RGas;     // 导入 Rooch 框架中的燃气代币模块，并引入 RGas 类型
    use rooch_framework::account_coin_store;  // 导入 Rooch 框架中的账户代币存储模块
    use nuwa_framework::message;             // 导入 nuwa_framework 中的消息模块
    use nuwa_framework::channel::{Self, Channel};  // 导入 nuwa_framework 中的通道模块，并引入 Channel 类型
    use nuwa_framework::agent;               // 导入 nuwa_framework 中的代理模块
    use nuwa_framework::agent_runner;        // 导入 nuwa_framework 中的代理运行模块

    const ErrorInvalidCoinType: u64 = 1;     // 定义错误码：无效代币类型
    const ErrorInvalidToAddress: u64 = 2;    // 定义错误码：无效目标地址

    
    /// Send a message and trigger AI response if needed  // 注释：发送消息并在需要时触发 AI 响应
    public entry fun send_message(           // 定义入口函数：发送消息
        caller: &signer,                     // 调用者签名者
        channel_obj: &mut Object<Channel>,   // 可变的通道对象
        content: String,                     // 消息内容
        mentions: vector<address>            // 提及的地址列表
    ) {
        channel::send_message(caller, channel_obj, content, mentions);  // 调用通道模块发送消息

        let mentioned_ai_agents = vector::empty();  // 初始化空的 AI 代理地址列表
        vector::for_each(mentions, |addr| {  // 遍历提及的地址
            if (agent::is_agent_account(addr) && !vector::contains(&mentioned_ai_agents, &addr)) {  // 如果是 AI 地址且未包含
                vector::push_back(&mut mentioned_ai_agents, addr);  // 添加到 AI 代理列表
            }
        });
        
        if (vector::length(&mentioned_ai_agents) > 0) {  // 如果有提及的 AI 代理
            
            vector::for_each(mentioned_ai_agents, |ai_addr| {  // 遍历 AI 代理地址
                let fee = coin::zero<RGas>();    // 创建零值的 RGas 费用
                call_agent(caller, channel_obj, ai_addr, fee);  // 调用代理处理函数
            });
        }
    }

    public entry fun send_message_with_coin<CoinType: key+store>(  // 定义入口函数：发送消息并附带代币
        caller: &signer,                     // 调用者签名者
        channel_obj: &mut Object<Channel>,   // 可变的通道对象
        content: String,                     // 消息内容
        to: address,                         // 目标地址
        amount: u256,                        // 代币数量
    ) {
        //Currently only support send coin to agent  // 注释：当前仅支持发送代币给代理
        assert!(agent::is_agent_account(to), ErrorInvalidToAddress);  // 断言：目标地址必须是代理地址
        let mentions = vector::empty();      // 初始化空的提及列表
        vector::push_back(&mut mentions, to);  // 将目标地址添加到提及列表
        channel::send_message(caller, channel_obj, content, mentions);  // 发送消息
        //currently only support RGas         // 注释：当前仅支持 RGas
        assert!(type_info::type_name<CoinType>() == type_info::type_name<RGas>(), ErrorInvalidCoinType);  // 断言：代币类型必须是 RGas
        let coin = account_coin_store::withdraw<RGas>(caller, amount);  // 从调用者账户提取 RGas
        call_agent(caller, channel_obj, to, coin);  // 调用代理处理函数并传递代币
    }

    fun call_agent(caller: &signer, channel_obj: &mut Object<Channel>, ai_addr: address, fee: Coin<RGas>) {  // 定义函数：调用代理
        let is_direct_channel = channel::get_channel_type(channel_obj) == channel::channel_type_ai_peer();  // 检查是否为一对一通道
        //TODO make the number of messages to fetch configurable  // 注释：待办事项：使消息获取数量可配置
        let message_limit: u64 = 11;         // 设置消息限制为 11 条
        let messages = channel::get_last_messages(channel_obj, message_limit);  // 获取最后 11 条消息
        
        let message_input = message::new_agent_input_v3(messages, is_direct_channel);  // 创建代理输入 V3
        let agent = agent::borrow_mut_agent_by_address(ai_addr);  // 根据地址借用可变的代理对象
        agent_runner::process_input_v2(caller, agent, message_input, fee);  // 调用代理运行模块处理输入
    }
}