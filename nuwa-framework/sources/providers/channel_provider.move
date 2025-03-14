module nuwa_framework::channel_provider {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use moveos_std::object::{Object};        // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use nuwa_framework::agent::{Agent};      // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::channel;             // 导入 nuwa_framework 中的通道模块
    use nuwa_framework::agent_state::{Self, AgentState};  // 导入 nuwa_framework 中的代理状态模块，并引入 AgentState 类型
    use nuwa_framework::string_utils::{channel_id_to_string};  // 导入 nuwa_framework 中的字符串工具模块，并引入 channel_id_to_string 函数

    #[data_struct]
    struct ChannelState has copy, drop, store {  // 定义通道状态结构体，具有 copy、drop、store 能力
        home_channel: String,                // 主通道标识（字符串形式）
    }

    public fun get_state(agent: &Object<Agent>): AgentState {  // 定义公开函数：获取代理的通道状态
        let home_channel_id = channel::get_agent_home_channel_id(agent);  // 获取代理的主通道 ID
        let home_channel = channel_id_to_string(home_channel_id);  // 将通道 ID 转换为字符串
        let channel_state = ChannelState {   // 创建 ChannelState 实例
            home_channel                     // 主通道
        };
        let state_json = string::utf8(json::to_json(&channel_state));  // 将通道状态转换为 JSON 字符串
        let agent_state = agent_state::new_agent_state(  // 创建 AgentState 实例
            string::utf8(b"Your channel state"),  // 状态描述
            state_json                        // 状态 JSON
        );
        agent_state                          // 返回代理状态
    }
}