module nuwa_framework::state_providers {
    use moveos_std::object::{Object};        // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use nuwa_framework::agent::{Agent};      // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::agent_state::{Self, AgentStates};  // 导入 nuwa_framework 中的代理状态模块，并引入 AgentStates 类型
    use nuwa_framework::balance_provider;    // 导入 nuwa_framework 中的余额提供者模块
    use nuwa_framework::channel_provider;    // 导入 nuwa_framework 中的通道提供者模块

    //Deprecated                            // 注释：已废弃
    public fun build_agent_state(_agent: &mut Object<Agent>): AgentStates {  // 定义公开函数：构建代理状态（已废弃）
        abort 0                              // 中止并抛出错误（无具体错误码）
    }

    public fun get_agent_state(agent: &Object<Agent>): AgentStates {  // 定义公开函数：获取代理状态
        let agent_states = agent_state::new_agent_states();  // 创建新的代理状态集合
        let balance_state = balance_provider::get_state(agent);  // 获取余额状态
        agent_state::add_agent_state(&mut agent_states, balance_state);  // 将余额状态添加到集合
        let channel_state = channel_provider::get_state(agent);  // 获取通道状态
        agent_state::add_agent_state(&mut agent_states, channel_state);  // 将通道状态添加到集合
        agent_states                         // 返回代理状态集合
    }
}