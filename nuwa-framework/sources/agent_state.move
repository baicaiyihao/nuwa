module nuwa_framework::agent_state {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::vector;                         // 导入标准库中的向量模块

    friend nuwa_framework::state_providers;  // 声明 state_providers 模块为友元模块
    friend nuwa_framework::agent;            // 声明 agent 模块为友元模块
    friend nuwa_framework::prompt_builder;   // 声明 prompt_builder 模块为友元模块

    #[data_struct]
    struct AgentState has copy, drop, store {  // 定义代理状态结构体，具有 copy、drop、store 能力
        description: String,                  // 状态描述
        state_json: String,                   // 状态的 JSON 表示
    }

    #[data_struct]
    struct AgentStates has copy, drop, store {  // 定义代理状态集合结构体，具有 copy、drop、store 能力
        states: vector<AgentState>,          // 代理状态列表
    }

    public(friend) fun new_agent_states(): AgentStates {  // 定义友元函数：创建新的代理状态集合
        AgentStates {                        // 创建并返回 AgentStates 实例
            states: vector::empty(),         // 初始化空的代理状态向量
        }
    }

    public fun new_agent_state(description: String, state_json: String): AgentState {  // 定义公开函数：创建新的代理状态
        AgentState {                         // 创建并返回 AgentState 实例
            description,                     // 状态描述
            state_json,                      // 状态 JSON
        }
    }

    public fun add_agent_state(agent_states: &mut AgentStates, agent_state: AgentState) {  // 定义公开函数：添加代理状态
        vector::push_back(&mut agent_states.states, agent_state);  // 将新状态添加到状态列表
    }

    //TODO change to &AgentStates              // 注释：待办事项：改为引用类型 &AgentStates
    public fun to_prompt(agent_states: AgentStates): String {  // 定义公开函数：将代理状态转换为提示字符串
        let prompt = string::utf8(b"Your current states:\n");  // 初始化提示字符串，标题为“Your current states:”
       
        vector::for_each(agent_states.states, |state| {  // 遍历代理状态列表
            let state: AgentState = state;       // 将状态转换为 AgentState 类型
            string::append(&mut prompt, state.description);  // 添加状态描述
            string::append(&mut prompt, string::utf8(b"\n"));  // 添加换行符
            string::append(&mut prompt, string::utf8(b"```json\n"));  // 添加 JSON 代码块开始标记
            string::append(&mut prompt, state.state_json);  // 添加状态 JSON
            string::append(&mut prompt, string::utf8(b"\n```\n"));  // 添加 JSON 代码块结束标记和换行
        });
        prompt                                   // 返回构建完成的提示字符串
    }
}