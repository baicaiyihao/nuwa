module nuwa_framework::task_entry {
    use std::string::String;                  // 导入标准库中的字符串模块
    use moveos_std::signer;                   // 导入 MoveOS 标准库中的签名者模块
    use moveos_std::object::{Self, ObjectID}; // 导入 MoveOS 标准库中的对象模块，并引入 ObjectID 类型
    use nuwa_framework::task;                 // 导入 nuwa_framework 中的任务模块
    use nuwa_framework::channel::{Self, Channel};  // 导入 nuwa_framework 中的通道模块，并引入 Channel 类型

    public entry fun start_task(resolver: &signer, task_id: ObjectID, message: String) {  // 定义公开入口函数：启动任务
        let resolver_address = signer::address_of(resolver);  // 获取签名者的地址（即任务解析者地址）
        let task = task::borrow_mut_task(task_id);  // 通过任务 ID 借用可变的任务对象
        task::start_task(resolver_address, task);   // 调用任务模块的 start_task 函数启动任务
        //The task object owner is the agent address  // 注释：任务对象的所有者是代理地址
        let agent_address = object::owner(task);    // 获取任务对象的所有者地址（代理地址）
        let channel_id = task::get_response_channel_id(task);  // 获取任务的响应通道 ID
        let channel_obj = object::borrow_mut_object_shared<Channel>(channel_id);  // 通过通道 ID 借用可变的共享通道对象
        channel::add_ai_response(channel_obj, message, agent_address);  // 向通道添加 AI 响应消息，附带代理地址
    }

    public entry fun resolve_task(resolver: &signer, task_id: ObjectID, result: String) {  // 定义公开入口函数：解决任务
        let resolver_address = signer::address_of(resolver);  // 获取签名者的地址（即任务解析者地址）
        let task = task::borrow_mut_task(task_id);  // 通过任务 ID 借用可变的任务对象
        task::resolve_task(resolver_address, task, result);  // 调用任务模块的 resolve_task 函数解决任务，并传入结果
        let agent_address = object::owner(task);    // 获取任务对象的所有者地址（代理地址）
        let channel_id = task::get_response_channel_id(task);  // 获取任务的响应通道 ID
        let channel_obj = object::borrow_mut_object_shared<Channel>(channel_id);  // 通过通道 ID 借用可变的共享通道对象
        channel::add_ai_response(channel_obj, result, agent_address);  // 向通道添加 AI 响应结果，附带代理地址
    }

    public entry fun fail_task(resolver: &signer, task_id: ObjectID, message: String) {  // 定义公开入口函数：标记任务失败
        let resolver_address = signer::address_of(resolver);  // 获取签名者的地址（即任务解析者地址）
        let task = task::borrow_mut_task(task_id);  // 通过任务 ID 借用可变的任务对象
        task::fail_task(resolver_address, task);    // 调用任务模块的 fail_task 函数标记任务失败
        let agent_address = object::owner(task);    // 获取任务对象的所有者地址（代理地址）
        let channel_id = task::get_response_channel_id(task);  // 获取任务的响应通道 ID
        let channel_obj = object::borrow_mut_object_shared<Channel>(channel_id);  // 通过通道 ID 借用可变的共享通道对象
        channel::add_ai_response(channel_obj, message, agent_address);  // 向通道添加 AI 响应消息，附带代理地址
    }
}