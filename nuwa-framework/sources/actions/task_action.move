module nuwa_framework::task_action {
    use std::string::{String};               // 导入标准库中的字符串模块，并引入 String 类型
    use std::option;                         // 导入标准库中的选项模块
    use moveos_std::object::{Object};        // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use moveos_std::result::{ok, err_str, Result};  // 导入 MoveOS 标准库中的结果模块，并引入相关类型和函数
    use nuwa_framework::task;                // 导入 nuwa_framework 中的任务模块
    use nuwa_framework::task_spec;           // 导入 nuwa_framework 中的任务规格模块
    use nuwa_framework::agent::{Self, Agent};  // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::response_action;     // 导入 nuwa_framework 中的响应动作模块
    use nuwa_framework::agent_input::{AgentInputInfoV2};  // 导入 nuwa_framework 中的代理输入模块，并引入 AgentInputInfoV2 类型

    friend nuwa_framework::action_dispatcher;  // 声明 action_dispatcher 模块为友元模块
    
    const TASK_ACTION_NAMESPACE: vector<u8> = b"task";  // 定义常量：任务动作命名空间
    
    public(friend) fun execute(agent: &mut Object<Agent>, agent_input: &AgentInputInfoV2, action_name: String, args_json: String): Result<bool, String> {  // 定义友元函数：执行任务动作
        let task_name = action_name;         // 将动作名称作为任务名称
        let agent_address = agent::get_agent_address(agent);  // 获取代理地址
        let response_channel_id = response_action::get_default_channel_id_from_input(agent_input);  // 从输入获取默认响应通道 ID
        let task_spec = agent::get_agent_task_spec(agent, task_name);  // 获取代理的任务规格
        if (option::is_none(&task_spec)) {   // 如果任务规格不存在
            return err_str(b"Task not found")  // 返回错误：任务未找到
        };
        let task_spec = option::destroy_some(task_spec);  // 提取任务规格
        let resolver = task_spec::get_task_resolver(&task_spec);  // 获取任务解析器
        let on_chain = task_spec::is_task_on_chain(&task_spec);  // 检查任务是否为链上任务
        task::publish_task(agent_address, task_name, args_json, response_channel_id, resolver, on_chain);  // 发布任务
        ok(true)                             // 返回成功结果
    }
}