module nuwa_framework::ai_callback {
    use std::option;                         // 导入标准库中的选项模块
    use std::vector;                         // 导入标准库中的向量模块
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型

    use moveos_std::object::{Self, ObjectID};  // 导入 MoveOS 标准库中的对象模块，并引入 ObjectID 类型
    use moveos_std::string_utils;            // 导入 MoveOS 标准库中的字符串工具模块
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::event;                   // 导入 MoveOS 标准库中的事件模块
    
    use verity::oracles;                     // 导入 verity 库中的预言机模块

    use nuwa_framework::agent::Agent;        // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::ai_service;          // 导入 nuwa_framework 中的 AI 服务模块
    use nuwa_framework::ai_response;         // 导入 nuwa_framework 中的 AI 响应模块
    use nuwa_framework::action_dispatcher;   // 导入 nuwa_framework 中的动作分发器模块

    struct PendingRequestNotFoundEvent has copy, drop, store {  // 定义未找到待处理请求事件结构体，具有 copy、drop、store 能力
        request_id: ObjectID,                // 请求 ID
    }

    struct AIOracleResponseErrorEvent has copy, drop, store {  // 定义 AI 预言机响应错误事件结构体，具有 copy、drop、store 能力
        request_id: ObjectID,                // 请求 ID
        error_message: String,               // 错误消息
    }

    public fun need_to_process_request(): bool {  // 定义公开函数：检查是否需要处理请求
        let pending_requests = ai_service::get_pending_requests_v3();  // 获取待处理请求 V3 列表
        let len = vector::length(&pending_requests);  // 获取列表长度
        let i = 0;                           // 初始化索引
        while (i < len) {                    // 遍历待处理请求
            let pending_request = vector::borrow(&pending_requests, i);  // 借用当前请求
            let (request_id, _agent_id, _agent_input_info) = ai_service::unpack_pending_request_v3(*pending_request);  // 解包请求信息
            let response_status = oracles::get_response_status(&request_id);  // 获取请求的响应状态
            if (response_status != 0) {      // 如果状态不为 0（表示有响应）
                return true                  // 返回 true，表示需要处理
            };
            i = i + 1;                       // 索引递增
        };
        false                                // 所有请求均未响应，返回 false
    }

    /// AI Oracle response processing callback, this function must be entry and no arguments  // 注释：AI 预言机响应处理回调，此函数必须是入口函数且无参数
    public entry fun process_response() {    // 定义入口函数：处理响应
        let pending_requests = ai_service::get_pending_requests_v3();  // 获取待处理请求 V3 列表
        
        vector::for_each(pending_requests, |pending_request| {  // 遍历每个待处理请求
            let (request_id, agent_id, agent_input_info) = ai_service::unpack_pending_request_v3(pending_request);  // 解包请求信息
            let response_status = oracles::get_response_status(&request_id);  // 获取响应状态
            
            if (response_status != 0) {      // 如果有响应（状态不为 0）
                let response = oracles::get_response(&request_id);  // 获取响应内容
                let response_content = option::destroy_some(response);  // 提取响应内容（假定响应存在）
                
                let message = if (response_status == 200) {  // 如果响应状态为 200（成功）
                    let json_str_opt = json::from_json_option<String>(string::into_bytes(response_content));  // 尝试解析响应为字符串
                    let json_str = if (option::is_some(&json_str_opt)) {  // 如果解析成功
                        option::destroy_some(json_str_opt)  // 提取字符串
                    } else {
                        response_content            // 否则使用原始内容
                    };
                    let chat_completion_opt = ai_response::parse_chat_completion_option(json_str);  // 尝试解析为 ChatCompletion
                    if (option::is_some(&chat_completion_opt)) {  // 如果解析成功
                        let chat_completion = option::destroy_some(chat_completion_opt);  // 提取 ChatCompletion
                        let message_content = ai_response::get_message_content(&chat_completion);  // 获取消息内容

                        let agent = object::borrow_mut_object_shared<Agent>(agent_id);  // 借用可变的代理对象
                        action_dispatcher::dispatch_actions_v3(agent, agent_input_info, message_content);  // 分发动作
                        let refusal = ai_response::get_refusal(&chat_completion);  // 获取拒绝原因
                        if (option::is_some(&refusal)) {  // 如果有拒绝原因
                            let refusal_reason = option::destroy_some(refusal);  // 提取拒绝原因
                            string::append(&mut message_content, string::utf8(b", refusal: "));  // 添加分隔符
                            string::append(&mut message_content, refusal_reason);  // 添加拒绝原因
                        };
                        message_content             // 返回消息内容
                    } else {
                        response_content            // 解析失败，返回原始内容
                    }
                } else {                        // 如果响应状态不为 200（错误）
                    let error_message = string::utf8(b"AI Oracle response error, error code: ");  // 初始化错误消息
                    string::append(&mut error_message, string_utils::to_string_u32((response_status as u32)));  // 添加错误码
                    string::append(&mut error_message, string::utf8(b", response: "));  // 添加分隔符
                    string::append(&mut error_message, response_content);  // 添加响应内容
                    error_message                // 返回错误消息
                };
                //TODO emit an event.             // 注释：待办事项：触发事件
                std::debug::print(&message);     // 打印消息（调试用）
                ai_service::remove_request(request_id);  // 从待处理请求中移除该请求
            };
        });
    }

    public entry fun process_response_v2(request_id: ObjectID) {  // 定义入口函数：处理响应 V2（指定请求 ID）
        let pending_request = ai_service::take_pending_request_by_id(request_id);  // 根据 ID 取出待处理请求
        if (option::is_some(&pending_request)) {  // 如果请求存在
            let pending_request = option::destroy_some(pending_request);  // 提取请求
            let (request_id, agent_id, agent_input_info) = ai_service::unpack_pending_request_v3(pending_request);  // 解包请求信息
            let response_status = oracles::get_response_status(&request_id);  // 获取响应状态
            if (response_status != 0) {      // 如果有响应
                let response = oracles::get_response(&request_id);  // 获取响应内容
                let response_content = option::destroy_some(response);  // 提取响应内容
                
                let error_message = if (response_status == 200) {  // 如果响应状态为 200（成功）
                    let json_str_opt = json::from_json_option<String>(string::into_bytes(response_content));  // 尝试解析为字符串
                    let json_str = if (option::is_some(&json_str_opt)) {  // 如果解析成功
                        option::destroy_some(json_str_opt)  // 提取字符串
                    } else {
                        response_content            // 否则使用原始内容
                    };
                    let chat_completion_opt = ai_response::parse_chat_completion_option(json_str);  // 尝试解析为 ChatCompletion
                    if (option::is_some(&chat_completion_opt)) {  // 如果解析成功
                        let chat_completion = option::destroy_some(chat_completion_opt);  // 提取 ChatCompletion
                        let message_content = ai_response::get_message_content(&chat_completion);  // 获取消息内容

                        let agent = object::borrow_mut_object_shared<Agent>(agent_id);  // 借用可变的代理对象
                        action_dispatcher::dispatch_actions_v3(agent, agent_input_info, message_content);  // 分发动作
                        let refusal = ai_response::get_refusal(&chat_completion);  // 获取拒绝原因
                        if (option::is_some(&refusal)) {  // 如果有拒绝原因
                            option::destroy_some(refusal)  // 提取但不使用（仅消耗 Option）
                        } else {
                            string::utf8(b"")       // 无拒绝原因，返回空字符串
                        }
                    } else {
                        response_content            // 解析失败，返回原始内容
                    }
                } else {                        // 如果响应状态不为 200（错误）
                    let error_message = string::utf8(b"AI Oracle response error, error code: ");  // 初始化错误消息
                    string::append(&mut error_message, string_utils::to_string_u32((response_status as u32)));  // 添加错误码
                    string::append(&mut error_message, string::utf8(b", response: "));  // 添加分隔符
                    string::append(&mut error_message, response_content);  // 添加响应内容
                    error_message                // 返回错误消息
                };
                let event = AIOracleResponseErrorEvent {  // 创建错误事件
                    request_id: request_id,      // 请求 ID
                    error_message,               // 错误消息
                };
                event::emit(event);              // 触发错误事件
            }; 
        } else {                             // 如果请求不存在
            let event = PendingRequestNotFoundEvent {  // 创建未找到请求事件
                request_id: request_id,      // 请求 ID
            };
            event::emit(event);              // 触发未找到事件
        }
    }
}