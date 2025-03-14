// Copyright (c) RoochNetwork
// SPDX-License-Identifier: Apache-2.0

module nuwa_framework::agent_cap {
    use moveos_std::object::{Self, Object, ObjectID};  // 导入 MoveOS 标准库中的对象模块，并引入 Object 和 ObjectID 类型
    use moveos_std::event;                   // 导入 MoveOS 标准库中的事件模块
    
    const ErrorAgentCapNotFound: u64 = 1;    // 定义错误码：代理能力未找到
    const ErrorCallerHasNoMemoryCap: u64 = 2;  // 定义错误码：调用者没有记忆能力
    const ErrorCallerHasNoMemoryCreateCap: u64 = 3;  // 定义错误码：调用者没有创建记忆的能力
    const ErrorCallerHasNoMemoryDeleteCap: u64 = 4;  // 定义错误码：调用者没有删除记忆的能力
    const ErrorCallerHasNoMemoryUpdateCap: u64 = 5;  // 定义错误码：调用者没有更新记忆的能力

    friend nuwa_framework::agent;            // 声明 agent 模块为友元模块

    struct AgentCap has store, key {         // 定义代理能力结构体，具有 store 和 key 能力
        agent_obj_id: ObjectID,              // 代理对象 ID
    }

    /// A cap for managing the memory of an agent.  // 注释：用于管理代理记忆的能力
    struct MemoryCap has store, key {        // 定义记忆能力结构体，具有 store 和 key 能力
        agent_obj_id: ObjectID,              // 代理对象 ID
        create: bool,                        // 是否有创建记忆的权限
        remove: bool,                        // 是否有删除记忆的权限
        update: bool,                        // 是否有更新记忆的权限
    }

    struct AgentCapDestroyedEvent has copy, drop, store {  // 定义代理能力销毁事件结构体，具有 copy、drop、store 能力
        agent_obj_id: ObjectID,              // 代理对象 ID
    }

    struct MemoryCapDestroyedEvent has copy, drop, store {  // 定义记忆能力销毁事件结构体，具有 copy、drop、store 能力
        agent_obj_id: ObjectID,              // 代理对象 ID
        create: bool,                        // 创建权限
        remove: bool,                        // 删除权限
        update: bool,                        // 更新权限
    }

    public(friend) fun new_agent_cap(agent_obj_id: ObjectID): Object<AgentCap> {  // 定义友元函数：创建新的代理能力对象
        let cap = AgentCap {                 // 创建 AgentCap 实例
            agent_obj_id,                    // 代理对象 ID
        };
        object::new(cap)                     // 将 AgentCap 封装为对象并返回
    }

    public(friend) fun new_memory_cap(agent_obj_id: ObjectID, create: bool, remove: bool, update: bool): Object<MemoryCap> {  // 定义友元函数：创建新的记忆能力对象
        let cap = MemoryCap {                // 创建 MemoryCap 实例
            agent_obj_id,                    // 代理对象 ID
            create,                          // 创建权限
            remove,                          // 删除权限
            update,                          // 更新权限
        };
        object::new(cap)                     // 将 MemoryCap 封装为对象并返回
    }

    public(friend) fun destroy_agent_cap(cap: Object<AgentCap>) {  // 定义友元函数：销毁代理能力对象
        let agent_cap = object::remove(cap);  // 从对象中移除 AgentCap
        let AgentCap { agent_obj_id } = agent_cap;  // 解构 AgentCap 获取代理对象 ID
        event::emit(AgentCapDestroyedEvent { agent_obj_id });  // 触发代理能力销毁事件
    }

    public entry fun destroy_memory_cap(cap: Object<MemoryCap>) {  // 定义入口函数：销毁记忆能力对象
        let memory_cap = object::remove(cap);  // 从对象中移除 MemoryCap
        let MemoryCap { agent_obj_id, create, remove, update } = memory_cap;  // 解构 MemoryCap 获取字段
        event::emit(MemoryCapDestroyedEvent { agent_obj_id, create, remove, update });  // 触发记忆能力销毁事件
    }

    public fun borrow_mut_agent_cap(caller: &signer, agent_obj_id: ObjectID): &mut Object<AgentCap> {  // 定义公开函数：借用可变的代理能力对象
        assert!(object::exists_object(agent_obj_id), ErrorAgentCapNotFound);  // 断言：确保代理能力对象存在，否则抛出未找到错误
        object::borrow_mut_object<AgentCap>(caller, agent_obj_id)  // 借用并返回可变的代理能力对象
    }

    public fun check_agent_cap(cap: &mut Object<AgentCap>): ObjectID {  // 定义公开函数：检查代理能力并返回代理对象 ID
        let cap = object::borrow(cap);       // 借用代理能力引用
        cap.agent_obj_id                     // 返回代理对象 ID
    }

    public fun check_memory_create_cap(cap: &mut Object<MemoryCap>): ObjectID {  // 定义公开函数：检查创建记忆能力并返回代理对象 ID
        let cap = object::borrow(cap);       // 借用记忆能力引用
        assert!(cap.create, ErrorCallerHasNoMemoryCreateCap);  // 断言：确保有创建权限，否则抛出无权限错误
        cap.agent_obj_id                     // 返回代理对象 ID
    }

    public fun check_memory_remove_cap(cap: &mut Object<MemoryCap>): ObjectID {  // 定义公开函数：检查删除记忆能力并返回代理对象 ID
        let cap = object::borrow(cap);       // 借用记忆能力引用
        assert!(cap.remove, ErrorCallerHasNoMemoryDeleteCap);  // 断言：确保有删除权限，否则抛出无权限错误
        cap.agent_obj_id                     // 返回代理对象 ID
    }

    public fun check_memory_update_cap(cap: &mut Object<MemoryCap>): ObjectID {  // 定义公开函数：检查更新记忆能力并返回代理对象 ID
        let cap = object::borrow(cap);       // 借用记忆能力引用
        assert!(cap.update, ErrorCallerHasNoMemoryUpdateCap);  // 断言：确保有更新权限，否则抛出无权限错误
        cap.agent_obj_id                     // 返回代理对象 ID
    }

    public fun get_agent_obj_id(cap: &Object<AgentCap>): ObjectID {  // 定义公开函数：获取代理能力中的代理对象 ID
        let cap = object::borrow(cap);       // 借用代理能力引用
        cap.agent_obj_id                     // 返回代理对象 ID
    }

    #[test_only]
    public fun issue_agent_cap_for_test(agent_obj_id: ObjectID): Object<AgentCap> {  // 定义仅测试函数：为测试发行代理能力对象
        new_agent_cap(agent_obj_id)          // 调用 new_agent_cap 创建并返回代理能力对象
    }

    #[test_only]
    public fun issue_memory_cap_for_test(agent_obj_id: ObjectID, create: bool, remove: bool, update: bool): Object<MemoryCap> {  // 定义仅测试函数：为测试发行记忆能力对象
        new_memory_cap(agent_obj_id, create, remove, update)  // 调用 new_memory_cap 创建并返回记忆能力对象
    }
}