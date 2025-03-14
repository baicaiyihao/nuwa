module nuwa_framework::agent_entry {
    use std::signer;                         // 导入标准库中的签名者模块
    use moveos_std::object::{Self, Object};  // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use nuwa_framework::character::{Character};  // 导入 nuwa_framework 中的角色模块，并引入 Character 类型
    use nuwa_framework::agent::{Self, Agent};  // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::agent_cap;           // 导入 nuwa_framework 中的代理能力模块
    use nuwa_framework::channel;             // 导入 nuwa_framework 中的通道模块

    //TODO remove this                        // 注释：待办事项：移除此函数
    public entry fun create_agent_entry(creater: &signer, character: Object<Character>) {  // 定义入口函数：创建代理（旧版）
        create_agent(creater, character);    // 调用新版创建代理函数
    }

    public entry fun create_agent(creater: &signer, character: Object<Character>) {  // 定义入口函数：创建代理
        let creater_addr = signer::address_of(creater);  // 获取创建者的地址
        let agent_cap = agent::create_agent(character);  // 创建代理并获取代理能力对象
        let agent_id = agent_cap::get_agent_obj_id(&agent_cap);  // 从代理能力对象中获取代理对象 ID
        let agent = object::borrow_mut_object_shared<Agent>(agent_id);  // 借用共享的可变代理对象
        let _channel_id = channel::create_ai_home_channel(agent);  // 创建 AI 主通道并获取通道 ID（未使用）
        object::transfer(agent_cap, creater_addr);  // 将代理能力对象转移给创建者
    }
}