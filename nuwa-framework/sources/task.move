module nuwa_framework::task {
    use std::string::String;                  // 导入标准库中的字符串模块
    use std::option::{Self, Option};         // 导入标准库中的选项模块，并引入 Option 类型
    use moveos_std::object::{Self, ObjectID, Object};  // 导入 MoveOS 标准库中的对象模块，包括 ObjectID 和 Object 类型
    use moveos_std::event;                    // 导入 MoveOS 标准库中的事件模块
    use moveos_std::event_queue;              // 导入 MoveOS 标准库中的事件队列模块
    use moveos_std::address;                  // 导入 MoveOS 标准库中的地址模块

    friend nuwa_framework::task_action;       // 声明 task_action 模块为友元模块
    friend nuwa_framework::task_entry;        // 声明 task_entry 模块为友元模块

    const ErrorInvalidTaskResolver: u64 = 1;  // 定义错误码：无效的任务解析者
    const ErrorInvalidTaskStatus: u64 = 2;    // 定义错误码：无效的任务状态

    const TASK_STATUS_PENDING: u8 = 0;        // 定义任务状态常量：待处理状态
    public fun task_status_pending(): u8 {    // 定义公开函数，返回待处理状态值
        TASK_STATUS_PENDING                   // 返回待处理状态常量
    }

    const TASK_STATUS_RUNNING: u8 = 1;        // 定义任务状态常量：运行中状态
    public fun task_status_running(): u8 {    // 定义公开函数，返回运行中状态值
        TASK_STATUS_RUNNING                   // 返回运行中状态常量
    }

    const TASK_STATUS_COMPLETED: u8 = 2;      // 定义任务状态常量：已完成状态
    public fun task_status_completed(): u8 {  // 定义公开函数，返回已完成状态值
        TASK_STATUS_COMPLETED                 // 返回已完成状态常量
    }

    const TASK_STATUS_FAILED: u8 = 3;         // 定义任务状态常量：失败状态
    public fun task_status_failed(): u8 {     // 定义公开函数，返回失败状态值
        TASK_STATUS_FAILED                    // 返回失败状态常量
    }
    
    struct Task has key {                     // 定义 Task 结构体，具有 key 能力
        name: String,                         // 任务名称，类型为字符串
        /// json string of arguments          // 注释：参数的 JSON 字符串
        arguments: String,                    // 任务参数，类型为字符串
        response_channel_id: ObjectID,        // 响应通道的 ID，类型为对象 ID
        result: Option<String>,               // 任务结果，类型为可选的字符串
        resolver: address,                    // 任务解析者的地址
        on_chain: bool,                       // 是否为链上任务，布尔值
        status: u8,                           // 任务状态，类型为 8 位无符号整数
    }

    struct TaskPublishEvent has copy, drop, store {  // 定义任务发布事件结构体，具有 copy、drop、store 能力
        agent_address: address,               // 代理地址
        task_id: ObjectID,                    // 任务对象的 ID
        name: String,                         // 任务名称
        arguments: String,                    // 任务参数
    }

    fun new_task(name: String, arguments: String, response_channel_id: ObjectID, resolver: address, on_chain: bool): Task {  // 定义函数：创建新任务
        Task {                                // 返回一个新的 Task 结构体实例
            name,                             // 任务名称
            arguments,                        // 任务参数
            response_channel_id,              // 响应通道 ID
            result: option::none(),           // 初始结果为空（无结果）
            resolver,                         // 任务解析者地址
            on_chain,                         // 是否链上任务
            status: task_status_pending(),    // 初始状态为待处理
        }
    }

    public(friend) fun publish_task(agent_address: address, name: String, arguments: String, response_channel_id: ObjectID, resolver: address, on_chain: bool): ObjectID {  // 定义友元函数：发布任务
        let task = new_task(name, arguments, response_channel_id, resolver, on_chain);  // 创建新任务
        let task_obj = object::new(task);     // 将任务封装为对象
        let task_obj_id = object::id(&task_obj);  // 获取任务对象的 ID
        object::transfer_extend(task_obj, agent_address);  // 将任务对象转移给代理地址
        if (on_chain) {                       // 如果是链上任务
            let name = address::to_string(&agent_address);  // 将代理地址转换为字符串
            event_queue::emit(name, TaskPublishEvent {  // 向事件队列发出任务发布事件
                agent_address,                // 代理地址
                task_id: task_obj_id,         // 任务 ID
                name,                         // 任务名称
                arguments,                    // 任务参数
            });
        } else {                              // 如果不是链上任务
            event::emit(TaskPublishEvent {    // 直接发出任务发布事件
                agent_address,                // 代理地址
                task_id: task_obj_id,         // 任务 ID
                name,                         // 任务名称
                arguments,                    // 任务参数
            });
        };
        task_obj_id                           // 返回任务对象的 ID
    }

    public(friend) fun borrow_mut_task(task_id: ObjectID): &mut Object<Task> {  // 定义友元函数：借用可变的任务对象
        let task_obj = object::borrow_mut_object_extend<Task>(task_id);  // 通过任务 ID 借用可变对象
        task_obj                              // 返回任务对象引用
    }

    public(friend) fun start_task(resolver: address, task_obj: &mut Object<Task>) {  // 定义友元函数：启动任务
        let task = object::borrow_mut(task_obj);  // 借用任务对象的可变引用
        assert!(task.resolver == resolver, ErrorInvalidTaskResolver);  // 断言：确保解析者地址匹配，否则抛出错误
        assert!(task.status == TASK_STATUS_PENDING, ErrorInvalidTaskStatus);  // 断言：确保任务状态为待处理，否则抛出错误
        task.status = TASK_STATUS_RUNNING;    // 将任务状态更新为运行中
    }

    public(friend) fun resolve_task(resolver: address, task_obj: &mut Object<Task>, result: String) {  // 定义友元函数：解决任务
        let task = object::borrow_mut(task_obj);  // 借用任务对象的可变引用
        assert!(task.resolver == resolver, ErrorInvalidTaskResolver);  // 断言：确保解析者地址匹配，否则抛出错误
        assert!(task.status == TASK_STATUS_PENDING || task.status == TASK_STATUS_RUNNING, ErrorInvalidTaskStatus);  // 断言：确保任务状态为待处理或运行中，否则抛出错误
        task.result = option::some(result);   // 设置任务结果为传入的结果
        task.status = TASK_STATUS_COMPLETED;  // 将任务状态更新为已完成
    }

    public(friend) fun fail_task(resolver: address, task_obj: &mut Object<Task>) {  // 定义友元函数：标记任务失败
        let task = object::borrow_mut(task_obj);  // 借用任务对象的可变引用
        assert!(task.resolver == resolver, ErrorInvalidTaskResolver);  // 断言：确保解析者地址匹配，否则抛出错误
        assert!(task.status == TASK_STATUS_PENDING || task.status == TASK_STATUS_RUNNING, ErrorInvalidTaskStatus);  // 断言：确保任务状态为待处理或运行中，否则抛出错误
        task.status = TASK_STATUS_FAILED;     // 将任务状态更新为失败
    }

    public fun get_status(task_obj: &Object<Task>): u8 {  // 定义公开函数：获取任务状态
        let task = object::borrow(task_obj);  // 借用任务对象的不可变引用
        task.status                           // 返回任务状态
    }

    public fun get_response_channel_id(task_obj: &Object<Task>): ObjectID {  // 定义公开函数：获取响应通道 ID
        let task = object::borrow(task_obj);  // 借用任务对象的不可变引用
        task.response_channel_id              // 返回响应通道 ID
    }

    public fun get_result(task_obj: &Object<Task>): Option<String> {  // 定义公开函数：获取任务结果
        let task = object::borrow(task_obj);  // 借用任务对象的不可变引用
        task.result                           // 返回任务结果
    }
}