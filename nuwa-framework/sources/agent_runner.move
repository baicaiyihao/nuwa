module nuwa_framework::agent_runner {
    use std::string::{String};               // 导入标准库中的字符串模块，并引入 String 类型
    use std::vector;                         // 导入标准库中的向量模块
    use moveos_std::object::{Self, Object};  // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use moveos_std::decimal_value;           // 导入 MoveOS 标准库中的十进制值模块
    use moveos_std::type_info;               // 导入 MoveOS 标准库中的类型信息模块

    use rooch_framework::coin::{Self, Coin};  // 导入 Rooch 框架中的代币模块，并引入 Coin 类型
    use rooch_framework::gas_coin::RGas;     // 导入 Rooch 框架中的燃气代币模块，并引入 RGas 类型
    use rooch_framework::account_coin_store;  // 导入 Rooch 框架中的账户代币存储模块

    use nuwa_framework::action::ActionGroup;  // 导入 nuwa_framework 中的动作模块，并引入 ActionGroup 类型
    use nuwa_framework::agent_input::{Self, AgentInput, CoinInputInfo};  // 导入 nuwa_framework 中的代理输入模块，并引入相关类型
    use nuwa_framework::ai_request;          // 导入 nuwa_framework 中的 AI 请求模块
    use nuwa_framework::ai_service;          // 导入 nuwa_framework 中的 AI 服务模块
    use nuwa_framework::prompt_builder;      // 导入 nuwa_framework 中的提示构建器模块
    use nuwa_framework::agent::{Self, Agent};  // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::action_dispatcher;   // 导入 nuwa_framework 中的动作分发器模块
    use nuwa_framework::state_providers;     // 导入 nuwa_framework 中的状态提供者模块

    public fun generate_system_prompt<I: copy + drop>(  // 定义公开函数：生成系统提示（已废弃）
        _agent: &Object<Agent>,                  // 代理对象引用
        _input: AgentInput<I>,                   // 输入数据
    ): String {
        abort 0                                  // 中止并抛出错误（无具体错误码）
    }

    public fun generate_system_prompt_v2<I: copy + drop>(  // 定义公开函数：生成系统提示 V2
        agent: &Object<Agent>,                   // 代理对象引用
        input: AgentInput<I>,                    // 输入数据
        input_coin: CoinInputInfo,               // 代币输入信息
    ): String {
        let states = state_providers::get_agent_state(agent);  // 获取代理状态
        std::debug::print(&states);              // 打印状态（调试用）
        let available_actions = get_available_actions(&input);  // 获取可用动作
        let agent_info = agent::get_agent_info_v2(agent);  // 获取代理信息 V2
        let memory_store = agent::borrow_memory_store(agent);  // 借用代理的记忆存储
        let task_specs = agent::get_agent_task_specs(agent);  // 获取代理的任务规格
        prompt_builder::build_complete_prompt_v3(  // 调用提示构建器生成完整提示
            agent_info,                          // 代理信息
            memory_store,                        // 记忆存储
            input,                               // 输入数据
            input_coin,                          // 代币输入信息
            available_actions,                   // 可用动作
            task_specs,                          // 任务规格
            states,                              // 代理状态
        )
    }

    public fun process_input<I: copy + drop>(    // 定义公开函数：处理输入（已废弃）
        _caller: &signer,                        // 调用者签名者
        _agent_obj: &mut Object<Agent>,          // 可变的代理对象
        _input: AgentInput<I>,                   // 输入数据
        _fee: Coin<RGas>,                        // 燃气费用
    ) {
       abort 0                                   // 中止并抛出错误（无具体错误码）
    }

    public fun process_input_v2<I: copy + drop + store>(  // 定义公开函数：处理输入 V2
        caller: &signer,                         // 调用者签名者
        agent_obj: &mut Object<Agent>,           // 可变的代理对象
        input: AgentInput<I>,                    // 输入数据
        fee: Coin<RGas>,                         // 燃气费用
    ) {
        //keep a fee argument for future usage.   // 注释：保留费用参数以备将来使用
        
        let agent_id = object::id(agent_obj);    // 获取代理对象 ID
        let model_provider = *agent::get_agent_model_provider(agent_obj);  // 获取模型提供者
        
        let input_info = agent_input::to_agent_input_info_v2(input);  // 将输入转换为 AgentInputInfoV2
        
        let coin_type = type_info::type_name<RGas>();  // 获取 RGas 的类型名称
        let coin_symbol = coin::symbol_by_type<RGas>();  // 获取 RGas 的符号
        let decimals = coin::decimals_by_type<RGas>();  // 获取 RGas 的小数位数
        let amount = coin::value(&fee);          // 获取费用的值
        let agent_addr = agent::get_agent_address(agent_obj);  // 获取代理地址
        account_coin_store::deposit<RGas>(agent_addr, fee);  // 将费用存入代理账户
        let coin_input_info = agent_input::new_coin_input_info(  // 创建代币输入信息
            coin_symbol,                         // 代币符号
            coin_type,                           // 代币类型
            decimal_value::new(amount, decimals),  // 十进制值（金额和小数位）
        );
        // Generate system prompt with context   // 注释：生成带有上下文的系统提示
        let system_prompt = generate_system_prompt_v2(  // 生成系统提示
            agent_obj,                           // 代理对象
            input,                               // 输入数据
            coin_input_info,                     // 代币输入信息
        );

        // Create chat messages                  // 注释：创建聊天消息
        let messages = vector::empty();          // 初始化空的消息向量
        
        // Add system message                   // 注释：添加系统消息
        vector::push_back(&mut messages, ai_request::new_system_chat_message(system_prompt));  // 添加系统提示消息

        // Create chat request                  // 注释：创建聊天请求
        let chat_request = ai_request::new_chat_request(  // 创建新的聊天请求
            model_provider,                      // 模型提供者
            messages,                            // 消息列表
        );

        // Call AI service                      // 注释：调用 AI 服务
        ai_service::request_ai(caller, agent_id, input_info, chat_request);  // 向 AI 服务发起请求

        agent::update_last_active_timestamp(agent_obj);  // 更新代理的最后活跃时间戳
    }

    fun get_available_actions<I: drop>(_input: &AgentInput<I>): vector<ActionGroup> {  // 定义函数：获取可用动作
        action_dispatcher::get_action_groups()   // 从动作分发器获取动作组并返回
    }
}