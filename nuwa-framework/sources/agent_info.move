module nuwa_framework::agent_info {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::vector;                         // 导入标准库中的向量模块
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::object::{ObjectID};      // 导入 MoveOS 标准库中的对象模块，并引入 ObjectID 类型

    #[data_struct]
    struct AgentInfo has copy, drop, store {  // 定义代理信息结构体，具有 copy、drop、store 能力
        id: ObjectID,                        // 代理 ID
        name: String,                        // 名称
        username: String,                    // 用户名
        avatar: String,                      // 头像（字符串表示，可能为 URL 或标识符）
        agent_address: address,              // 代理地址
        description: String,                 // 描述
        bio: vector<String>,                 // 简介（多行文本）
        knowledge: vector<String>,           // 知识库（多行文本）
        model_provider: String,              // 模型提供者
    }

    public fun new_agent_info(                // 定义公开函数：创建新的代理信息
        id: ObjectID,                        // 代理 ID
        name: String,                        // 名称
        username: String,                    // 用户名
        avatar: String,                      // 头像
        agent_address: address,              // 代理地址
        description: String,                 // 描述
        bio: vector<String>,                 // 简介
        knowledge: vector<String>,           // 知识库
        model_provider: String,              // 模型提供者
    ): AgentInfo {                           // 返回 AgentInfo 类型
        AgentInfo {                          // 创建并返回 AgentInfo 实例
            id,                              // ID
            name,                            // 名称
            username,                        // 用户名
            avatar,                          // 头像
            agent_address,                   // 代理地址
            description,                     // 描述
            bio,                             // 简介
            knowledge,                       // 知识库
            model_provider,                  // 模型提供者
        }
    }

    // ============ Getters ============      // 注释：获取函数
    public fun get_id(agent_info: &AgentInfo): ObjectID {  // 定义公开函数：获取代理 ID
        agent_info.id                        // 返回代理 ID
    }

    public fun get_name(agent_info: &AgentInfo): &String {  // 定义公开函数：获取名称
        &agent_info.name                     // 返回名称的引用
    }

    public fun get_username(agent_info: &AgentInfo): &String {  // 定义公开函数：获取用户名
        &agent_info.username                 // 返回用户名的引用
    }

    public fun get_avatar(agent_info: &AgentInfo): &String {  // 定义公开函数：获取头像
        &agent_info.avatar                   // 返回头像的引用
    }

    public fun get_agent_address(agent_info: &AgentInfo): address {  // 定义公开函数：获取代理地址
        agent_info.agent_address             // 返回代理地址
    }

    public fun get_description(agent_info: &AgentInfo): &String {  // 定义公开函数：获取描述
        &agent_info.description              // 返回描述的引用
    }

    public fun get_bio(agent_info: &AgentInfo): &vector<String> {  // 定义公开函数：获取简介
        &agent_info.bio                      // 返回简介向量的引用
    }

    public fun get_knowledge(agent_info: &AgentInfo): &vector<String> {  // 定义公开函数：获取知识库
        &agent_info.knowledge                // 返回知识库向量的引用
    }

    public fun get_model_provider(agent_info: &AgentInfo): &String {  // 定义公开函数：获取模型提供者
        &agent_info.model_provider           // 返回模型提供者的引用
    }

    /// The PromptAgentInfo struct is used to display agent information in a prompt  // 注释：PromptAgentInfo 结构体用于在提示中显示代理信息
    struct PromptAgentInfo has copy, drop, store {  // 定义提示代理信息结构体，具有 copy、drop、store 能力
        name: String,                        // 名称
        username: String,                    // 用户名
        avatar: String,                      // 头像
        agent_address: address,              // 代理地址
        description: String,                 // 描述
        bio: vector<String>,                 // 简介
        knowledge: vector<String>,           // 知识库
        model_provider: String,              // 模型提供者
    }

    public fun to_prompt(agent_info: &AgentInfo): String {  // 定义公开函数：将代理信息转换为提示字符串
        let prompt_agent_info = PromptAgentInfo {  // 创建 PromptAgentInfo 实例
            name: agent_info.name,           // 名称
            username: agent_info.username,   // 用户名
            avatar: agent_info.avatar,       // 头像
            agent_address: agent_info.agent_address,  // 代理地址
            description: agent_info.description,  // 描述
            bio: agent_info.bio,             // 简介
            knowledge: agent_info.knowledge, // 知识库
            model_provider: agent_info.model_provider,  // 模型提供者
        };
        let prompt = b"```json\n";           // 初始化提示字符串，添加 JSON 代码块开始标记
        vector::append(&mut prompt, json::to_json(&prompt_agent_info));  // 将代理信息转换为 JSON 并追加
        vector::append(&mut prompt, b"\n```");  // 添加 JSON 代码块结束标记
        string::utf8(prompt)                 // 将字节向量转换为字符串并返回
    }
}