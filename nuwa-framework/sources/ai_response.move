module nuwa_framework::ai_response {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::option::Option;                 // 导入标准库中的选项模块，并引入 Option 类型
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use std::vector;                         // 导入标准库中的向量模块

    #[data_struct]
    struct Usage has copy, drop, store {     // 定义使用情况结构体，具有 copy、drop、store 能力
        prompt_tokens: u64,                  // 提示令牌数
        completion_tokens: u64,              // 完成令牌数
        total_tokens: u64,                   // 总令牌数
    }

    #[data_struct]
    struct Message has copy, drop, store {   // 定义消息结构体，具有 copy、drop、store 能力
        role: String,                        // 角色（如 "assistant"）
        content: String,                     // 消息内容
        refusal: Option<String>,             // 拒绝原因（可选）
    }

    #[data_struct]
    struct Choice has copy, drop, store {    // 定义选择结构体，具有 copy、drop、store 能力
        index: u64,                          // 选择索引
        message: Message,                    // 消息
        finish_reason: String,               // 完成原因（如 "stop"）
    }

    #[data_struct]
    struct ChatCompletion has copy, drop, store {  // 定义聊天完成结构体，具有 copy、drop、store 能力
        id: String,                          // 完成 ID
        object: String,                      // 对象类型（如 "chat.completion"）
        created: u64,                        // 创建时间戳
        model: String,                       // 使用的模型名称
        choices: vector<Choice>,             // 选择列表
        usage: Usage,                        // 使用情况
    }

    public fun parse_chat_completion(json_str: String): ChatCompletion {  // 定义公开函数：解析聊天完成 JSON
        json::from_json<ChatCompletion>(string::into_bytes(json_str))  // 从 JSON 字符串解析出 ChatCompletion
    }

    public fun parse_chat_completion_option(json_str: String): Option<ChatCompletion> {  // 定义公开函数：解析聊天完成 JSON（返回 Option）
        json::from_json_option<ChatCompletion>(string::into_bytes(json_str))  // 从 JSON 字符串解析出 ChatCompletion（可能为空）
    }

    /// Get the message content from the first choice in the completion  // 注释：从完成中的第一个选择获取消息内容
    public fun get_message_content(completion: &ChatCompletion): String {  // 定义公开函数：获取消息内容
        let choice = vector::borrow(&completion.choices, 0);  // 借用第一个选择
        choice.message.content                        // 返回消息内容
    }

    /// Get the refusal reason if present      // 注释：获取拒绝原因（如果存在）
    public fun get_refusal(completion: &ChatCompletion): Option<String> {  // 定义公开函数：获取拒绝原因
        let choice = vector::borrow(&completion.choices, 0);  // 借用第一个选择
        choice.message.refusal                        // 返回拒绝原因（可能为空）
    }

    /// Get the finish reason from the first choice  // 注释：从第一个选择获取完成原因
    public fun get_finish_reason(completion: &ChatCompletion): String {  // 定义公开函数：获取完成原因
        let choice = vector::borrow(&completion.choices, 0);  // 借用第一个选择
        choice.finish_reason                          // 返回完成原因
    }

    /// Get total tokens used                 // 注释：获取使用的总令牌数
    public fun get_total_tokens(completion: &ChatCompletion): u64 {  // 定义公开函数：获取总令牌数
        completion.usage.total_tokens                 // 返回总令牌数
    }

    /// Get completion model name             // 注释：获取完成模型名称
    public fun get_model(completion: &ChatCompletion): String {  // 定义公开函数：获取模型名称
        completion.model                              // 返回模型名称
    }

    /// Get assistant's role                  // 注释：获取助手的角色
    public fun get_assistant_role(completion: &ChatCompletion): String {  // 定义公开函数：获取助手角色
        let choice = vector::borrow(&completion.choices, 0);  // 借用第一个选择
        choice.message.role                           // 返回角色
    }

    /// Check if the completion has any refusal  // 注释：检查完成是否包含拒绝
    public fun has_refusal(completion: &ChatCompletion): bool {  // 定义公开函数：检查是否有拒绝
        let choice = vector::borrow(&completion.choices, 0);  // 借用第一个选择
        std::option::is_some(&choice.message.refusal)  // 返回是否存在拒绝原因
    }

    #[test]
    fun test_parse_chat_completion() {       // 定义测试函数：测试解析聊天完成
        let json_str = string::utf8(b"{\"id\":\"chatcmpl-Az3dpZskp51c4DlFzLVmgjoM3B56Z\",\"object\":\"chat.completion\",\"created\":1739115369,\"model\":\"gpt-4-0613\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"Hello! How can I assist you today?\",\"refusal\":null},\"logprobs\":null,\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":10,\"total_tokens\":18}}");  // 定义测试用的 JSON 字符串

        let completion = parse_chat_completion(json_str);  // 解析 JSON 字符串为 ChatCompletion
        
        // Test basic fields                 // 注释：测试基本字段
        assert!(completion.id == string::utf8(b"chatcmpl-Az3dpZskp51c4DlFzLVmgjoM3B56Z"), 1);  // 断言：ID 正确
        assert!(completion.object == string::utf8(b"chat.completion"), 2);  // 断言：对象类型正确
        assert!(completion.created == 1739115369, 3);  // 断言：创建时间正确
        assert!(completion.model == string::utf8(b"gpt-4-0613"), 4);  // 断言：模型名称正确

        // Test choices                     // 注释：测试选择
        assert!(vector::length(&completion.choices) == 1, 5);  // 断言：选择数量为 1
        let choice = vector::borrow(&completion.choices, 0);  // 借用第一个选择
        assert!(choice.index == 0, 6);        // 断言：索引为 0
        assert!(choice.finish_reason == string::utf8(b"stop"), 7);  // 断言：完成原因为 "stop"

        // Test message                     // 注释：测试消息
        let message = &choice.message;        // 获取消息引用
        assert!(message.role == string::utf8(b"assistant"), 8);  // 断言：角色为 "assistant"
        assert!(message.content == string::utf8(b"Hello! How can I assist you today?"), 9);  // 断言：内容正确
        assert!(std::option::is_none(&message.refusal), 10);  // 断言：无拒绝原因

        // Test usage                       // 注释：测试使用情况
        assert!(completion.usage.prompt_tokens == 8, 11);  // 断言：提示令牌数为 8
        assert!(completion.usage.completion_tokens == 10, 12);  // 断言：完成令牌数为 10
        assert!(completion.usage.total_tokens == 18, 13);  // 断言：总令牌数为 18
    }

    #[test]
    fun test_getters() {                     // 定义测试函数：测试获取函数
        let json_str = string::utf8(b"{\"id\":\"chatcmpl-Az3dpZskp51c4DlFzLVmgjoM3B56Z\",\"object\":\"chat.completion\",\"created\":1739115369,\"model\":\"gpt-4-0613\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"Hello! How can I assist you today?\",\"refusal\":null},\"logprobs\":null,\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":10,\"total_tokens\":18}}");  // 定义测试用的 JSON 字符串

        let completion = parse_chat_completion(json_str);  // 解析 JSON 字符串为 ChatCompletion
        
        assert!(get_message_content(&completion) == string::utf8(b"Hello! How can I assist you today?"), 1);  // 断言：消息内容正确
        assert!(get_finish_reason(&completion) == string::utf8(b"stop"), 2);  // 断言：完成原因为 "stop"
        assert!(get_total_tokens(&completion) == 18, 3);  // 断言：总令牌数为 18
        assert!(get_model(&completion) == string::utf8(b"gpt-4-0613"), 4);  // 断言：模型名称正确
        assert!(get_assistant_role(&completion) == string::utf8(b"assistant"), 5);  // 断言：助手角色正确
        assert!(!has_refusal(&completion), 6);  // 断言：无拒绝
        assert!(std::option::is_none(&get_refusal(&completion)), 7);  // 断言：拒绝原因为空
    }
}