module nuwa_framework::ai_request {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块

    #[data_struct]
    struct ChatMessage has store, copy, drop {  // 定义聊天消息结构体，具有 store、copy、drop 能力
        role: String,                        // 角色（如 "system"、"user"、"assistant"）
        content: String,                     // 消息内容
    }

    #[data_struct]
    struct ChatRequest has store, copy, drop {  // 定义聊天请求结构体，具有 store、copy、drop 能力
        model: String,                       // 模型名称
        messages: vector<ChatMessage>,       // 消息列表
        //TODO use Decimal type               // 注释：待办事项：使用 Decimal 类型
        temperature: u64,                    // 温度参数（控制生成内容的随机性）
    }

    public fun new_chat_request(model: String, messages: vector<ChatMessage>): ChatRequest {  // 定义公开函数：创建新的聊天请求
        ChatRequest {                        // 创建并返回 ChatRequest 实例
            model,                           // 模型名称
            messages,                        // 消息列表
            temperature: 1,                  // 默认温度值为 1
        }
    }

    public fun new_chat_message(role: String, content: String): ChatMessage {  // 定义公开函数：创建新的聊天消息
        ChatMessage {                        // 创建并返回 ChatMessage 实例
            role,                            // 角色
            content,                         // 内容
        }
    }

    public fun new_system_chat_message(content: String): ChatMessage {  // 定义公开函数：创建新的系统聊天消息
        new_chat_message(string::utf8(b"system"), content)  // 调用 new_chat_message，角色为 "system"
    }

    public fun new_user_chat_message(content: String): ChatMessage {  // 定义公开函数：创建新的用户聊天消息
        new_chat_message(string::utf8(b"user"), content)  // 调用 new_chat_message，角色为 "user"
    }

    public fun new_assistant_chat_message(content: String): ChatMessage {  // 定义公开函数：创建新的助手聊天消息
        new_chat_message(string::utf8(b"assistant"), content)  // 调用 new_chat_message，角色为 "assistant"
    }

    public fun to_json(request: &ChatRequest): vector<u8> {  // 定义公开函数：将聊天请求转换为 JSON
        json::to_json(request)               // 将 ChatRequest 转换为 JSON 字节向量并返回
    }
}