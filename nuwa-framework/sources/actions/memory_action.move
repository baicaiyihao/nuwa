module nuwa_framework::memory_action {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::option::{Self, Option};         // 导入标准库中的选项模块，并引入 Option 类型
    use std::vector;                         // 导入标准库中的向量模块
    
    use moveos_std::object::Object;          // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::result::{ok, err_str, Result};  // 导入 MoveOS 标准库中的结果模块，并引入相关类型和函数

    use nuwa_framework::agent::{Self, Agent};  // 导入 nuwa_framework 中的代理模块，并引入 Agent 类型
    use nuwa_framework::memory;              // 导入 nuwa_framework 中的记忆模块
    use nuwa_framework::action::{Self, ActionGroup};  // 导入 nuwa_framework 中的动作模块，并引入 ActionGroup 类型
    use nuwa_framework::agent_input::{Self, AgentInputInfo, AgentInputInfoV2};  // 导入 nuwa_framework 中的代理输入模块，并引入相关类型

    /// 使用更直观的命名空间定义记忆动作名称
    const ACTION_NAME_REMEMBER_SELF: vector<u8> = b"memory::remember_self";  // 记住自己的动作名称
    public fun action_name_remember_self(): String { string::utf8(ACTION_NAME_REMEMBER_SELF) }  // 获取记住自己的动作名称
    const ACTION_NAME_REMEMBER_USER: vector<u8> = b"memory::remember_user";  // 记住用户的动作名称
    public fun action_name_remember_user(): String { string::utf8(ACTION_NAME_REMEMBER_USER) }  // 获取记住用户的动作名称
    const ACTION_NAME_UPDATE_SELF: vector<u8> = b"memory::update_self";  // 更新自己的动作名称
    public fun action_name_update_self(): String { string::utf8(ACTION_NAME_UPDATE_SELF) }  // 获取更新自己的动作名称
    const ACTION_NAME_UPDATE_USER: vector<u8> = b"memory::update_user";  // 更新用户的动作名称
    public fun action_name_update_user(): String { string::utf8(ACTION_NAME_UPDATE_USER) }  // 获取更新用户的动作名称
    
    // 添加新的 memory::none 动作
    const ACTION_NAME_NONE: vector<u8> = b"memory::none";  // 无记忆动作名称
    public fun action_name_none(): String { string::utf8(ACTION_NAME_NONE) }  // 获取无记忆动作名称

    /// 标记“已删除”记忆的特殊内容
    const MEMORY_DELETED_MARK: vector<u8> = b"[deleted]";

    // 上下文常量 - 保留向后兼容性
    public fun context_personal(): String { memory::context_personal() }  // 获取个人上下文
    public fun context_interaction(): String { memory::context_interaction() }  // 获取交互上下文
    public fun context_knowledge(): String { memory::context_knowledge() }  // 获取知识上下文
    public fun context_emotional(): String { memory::context_emotional() }  // 获取情感上下文
    public fun context_goal(): String { memory::context_goal() }  // 获取目标上下文
    public fun context_preference(): String { memory::context_preference() }  // 获取偏好上下文
    public fun context_feedback(): String { memory::context_feedback() }  // 获取反馈上下文
    public fun context_rule(): String { memory::context_rule() }  // 获取规则上下文
    
    /// 检查上下文是否有效
    /// 参数：
    /// - context: 上下文字符串引用
    /// 返回：是否为有效上下文
    public fun is_valid_context(context: &String): bool {
        memory::is_standard_context(context)  // 调用记忆模块检查标准上下文
    }

    // TODO: 移除此结构
    #[data_struct]
    /// 添加记忆动作的参数
    struct AddMemoryArgs has copy, drop {
        target: address,     // 目标地址
        content: String,     // 记忆内容
        context: String,     // 记忆的上下文标签
        is_long_term: bool,  // 是否为长期记忆
    }

    #[data_struct]
    /// 添加关于自己的记忆参数
    struct RememberSelfArgs has copy, drop {
        content: String,     // 记忆内容
        context: String,     // 记忆的上下文标签
        is_long_term: bool,  // 是否为长期记忆
    }

    /// 创建记住自己参数
    /// 参数：
    /// - content: 内容
    /// - context: 上下文
    /// - is_long_term: 是否为长期记忆
    /// 返回：RememberSelfArgs 实例
    public fun create_remember_self_args(
        content: String,
        context: String,
        is_long_term: bool
    ): RememberSelfArgs {
        RememberSelfArgs {
            content,
            context,
            is_long_term
        }
    }

    // TODO: 移除此结构
    #[data_struct]
    /// 更新记忆动作的参数
    struct UpdateMemoryArgs has copy, drop {
        target: address,     // 目标地址
        index: u64,          // 记忆索引
        // TODO: 将 new_content 重命名为 content，new_context 重命名为 context
        new_content: String, // 新记忆内容
        new_context: String, // 新上下文标签（可选）
        is_long_term: bool,  // 是否为长期记忆
    }

    #[data_struct]
    /// 添加关于用户的记忆参数
    struct RememberUserArgs has copy, drop {
        content: String,     // 记忆内容
        context: String,     // 记忆的上下文标签
        is_long_term: bool,  // 是否为长期记忆
    }

    /// 创建记住用户参数
    /// 参数：
    /// - content: 内容
    /// - context: 上下文
    /// - is_long_term: 是否为长期记忆
    /// 返回：RememberUserArgs 实例
    public fun create_remember_user_args(
        content: String,
        context: String,
        is_long_term: bool
    ): RememberUserArgs {
        RememberUserArgs {
            content,
            context,
            is_long_term
        }
    }

    #[data_struct]
    /// 更新关于自己的记忆参数
    struct UpdateSelfMemoryArgs has copy, drop {
        index: u64,          // 记忆索引
        new_content: String, // 新记忆内容
        new_context: String, // 新上下文标签
        is_long_term: bool,  // 是否为长期记忆
    }

    /// 创建更新自己记忆参数
    /// 参数：
    /// - index: 索引
    /// - new_content: 新内容
    /// - new_context: 新上下文
    /// - is_long_term: 是否为长期记忆
    /// 返回：UpdateSelfMemoryArgs 实例
    public fun create_update_self_memory_args(
        index: u64,
        new_content: String,
        new_context: String,
        is_long_term: bool
    ): UpdateSelfMemoryArgs {
        UpdateSelfMemoryArgs {
            index,
            new_content,
            new_context,
            is_long_term
        }
    }

    #[data_struct]
    /// 更新关于用户的记忆参数
    struct UpdateUserMemoryArgs has copy, drop {
        index: u64,          // 记忆索引
        new_content: String, // 新记忆内容
        new_context: String, // 新上下文标签
        is_long_term: bool,  // 是否为长期记忆
    }

    /// 创建更新用户记忆参数
    /// 参数：
    /// - index: 索引
    /// - new_content: 新内容
    /// - new_context: 新上下文
    /// - is_long_term: 是否为长期记忆
    /// 返回：UpdateUserMemoryArgs 实例
    public fun create_update_user_memory_args(
        index: u64,
        new_content: String,
        new_context: String,
        is_long_term: bool
    ): UpdateUserMemoryArgs {
        UpdateUserMemoryArgs {
            index,
            new_content,
            new_context,
            is_long_term
        }
    }

    // TODO: 移除此函数
    /// 创建添加记忆动作参数
    public fun create_add_memory_args(
        target: address,
        content: String,
        context: String,
        is_long_term: bool
    ): AddMemoryArgs {
        AddMemoryArgs {
            target,
            content,
            context,
            is_long_term
        }
    }

    // TODO: 移除此函数
    /// 创建更新记忆动作参数
    public fun create_update_memory_args(
        target: address,
        index: u64,
        new_content: String,
        new_context: String,
        is_long_term: bool
    ): UpdateMemoryArgs {
        UpdateMemoryArgs {
            target,
            index,
            new_content,
            new_context,
            is_long_term
        }
    }

    // 动作示例 - 简化示例以便 AI 理解
    const REMEMBER_SELF_EXAMPLE: vector<u8> = b"{\"content\":\"I find that I connect well with users who share personal stories\",\"context\":\"personal\",\"is_long_term\":true}";
    const REMEMBER_USER_EXAMPLE: vector<u8> = b"{\"content\":\"User prefers detailed technical explanations\",\"context\":\"preference\",\"is_long_term\":true}";
    const UPDATE_SELF_EXAMPLE: vector<u8> = b"{\"index\":2,\"new_content\":\"I've noticed I'm more effective when I ask clarifying questions\",\"new_context\":\"personal\",\"is_long_term\":true}";
    const UPDATE_USER_EXAMPLE: vector<u8> = b"{\"index\":3,\"new_content\":\"User now prefers concise explanations with code examples\",\"new_context\":\"preference\",\"is_long_term\":true}";

    // 为 memory::none 动作添加示例
    const NONE_EXAMPLE: vector<u8> = b"{\"reason\":null}";

    #[data_struct]
    /// memory::none 动作的参数
    struct NoneArgs has copy, drop {
        reason: Option<String>,     // 可选的理由，表示不创建记忆的原因
    }

    /// 创建无记忆参数
    /// 参数：
    /// - reason: 理由（可选）
    /// 返回：NoneArgs 实例
    public fun create_none_args(
        reason: Option<String>
    ): NoneArgs {
        NoneArgs {
            reason
        }
    }

    /// 注册动作（已废弃）
    public fun register_actions() {
        // TODO: 已废弃，需移除
    }

    /// 获取动作组
    /// 返回：包含记忆动作的 ActionGroup
    public fun get_action_group(): ActionGroup {
        action::new_action_group(
            string::utf8(b"memory"),         // 命名空间：memory
            string::utf8(b"Memory actions for storing and updating personal and user memories. You MUST use at least one memory action (or memory::none) in EVERY interaction."),  // 描述：记忆动作用于存储和更新个人及用户记忆，每次交互必须使用至少一个记忆动作（或 memory::none）
            get_action_descriptions()        // 获取动作描述列表
        )   
    }

    /// 获取动作描述
    /// 返回：包含所有记忆动作描述的向量
    public fun get_action_descriptions(): vector<action::ActionDescription> {
        let descriptions = vector::empty();  // 初始化空描述向量
        
        // 首先添加 memory::none 动作，明确记忆动作的要求
        let none_args = vector[              // 创建无记忆动作参数列表
            action::new_action_argument(     // 参数：理由
                string::utf8(b"reason"),     // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"Optional reason why no memory should be created"),  // 描述：可选理由，表示不创建记忆的原因
                false,                       // 是否必需（可选）
            ),
        ];

        vector::push_back(&mut descriptions, action::new_action_description(  // 添加无记忆动作描述
            string::utf8(ACTION_NAME_NONE),  // 动作名称
            string::utf8(b"Explicitly indicate that nothing should be remembered from this interaction"),  // 描述：明确表示当前交互无需记忆
            none_args,                       // 参数列表
            string::utf8(NONE_EXAMPLE),      // 参数示例
            string::utf8(b"You MUST use at least one memory action in each interaction - use this action if there's nothing to remember"),  // 使用提示：每交互必须使用一个记忆动作，若无内容可记则使用此动作
            string::utf8(b"Using this action acknowledges that you've considered memory but determined there's nothing important to record"),  // 约束：使用此动作表示已考虑记忆但认为无重要内容记录
        ));

        // 注册记住自己动作（AI 关于自身的记忆）
        let remember_self_args = vector[     // 创建记住自己动作参数列表
            action::new_action_argument(     // 参数：内容
                string::utf8(b"content"),    // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The content of your memory about yourself"),  // 描述：关于自己的记忆内容
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：上下文
                string::utf8(b"context"),    // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The context tag for your memory (personal, goal, etc.)"),  // 描述：记忆的上下文标签（personal, goal 等）
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：是否长期
                string::utf8(b"is_long_term"),  // 参数名称
                string::utf8(b"bool"),       // 类型描述
                string::utf8(b"Whether to store as a permanent memory"),  // 描述：是否作为永久记忆存储
                true,                        // 是否必需
            ),
        ];

        vector::push_back(&mut descriptions, action::new_action_description(  // 添加记住自己动作描述
            string::utf8(ACTION_NAME_REMEMBER_SELF),  // 动作名称
            string::utf8(b"Remember something about yourself"),  // 描述：记住关于自己的内容
            remember_self_args,              // 参数列表
            string::utf8(REMEMBER_SELF_EXAMPLE),  // 参数示例
            string::utf8(b"Use this to record your own thoughts, feelings, goals, or personal development"),  // 使用提示：用于记录自己的想法、情感、目标或个人发展
            string::utf8(b"Self-memories help you maintain continuity of identity"),  // 约束：自我记忆有助于保持身份连续性
        ));

        // 注册记住用户动作（AI 关于用户的记忆）
        let remember_user_args = vector[     // 创建记住用户动作参数列表
            action::new_action_argument(     // 参数：内容
                string::utf8(b"content"),    // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The content of your memory about the user"),  // 描述：关于用户的记忆内容
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：上下文
                string::utf8(b"context"),    // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The context tag for your memory (preference, feedback, etc.)"),  // 描述：记忆的上下文标签（preference, feedback 等）
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：是否长期
                string::utf8(b"is_long_term"),  // 参数名称
                string::utf8(b"bool"),       // 类型描述
                string::utf8(b"Whether to store as a permanent memory"),  // 描述：是否作为永久记忆存储
                true,                        // 是否必需
            ),
        ];

        vector::push_back(&mut descriptions, action::new_action_description(  // 添加记住用户动作描述
            string::utf8(ACTION_NAME_REMEMBER_USER),  // 动作名称
            string::utf8(b"Remember something about the current user"),  // 描述：记住关于当前用户的內容
            remember_user_args,              // 参数列表
            string::utf8(REMEMBER_USER_EXAMPLE),  // 参数示例
            string::utf8(b"Use this to record important information about the user you're speaking with"),  // 使用提示：用于记录与用户对话的重要信息
            string::utf8(b"User memories help you personalize future interactions"),  // 约束：用户记忆有助于个性化未来交互
        ));

        // 注册更新自己动作（更新 AI 关于自身的记忆）
        let update_self_args = vector[       // 创建更新自己动作参数列表
            action::new_action_argument(     // 参数：索引
                string::utf8(b"index"),      // 参数名称
                string::utf8(b"u64"),        // 类型描述
                string::utf8(b"The index of your memory to update"),  // 描述：要更新的记忆索引
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：新内容
                string::utf8(b"new_content"),  // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The updated content"),  // 描述：更新后的内容
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：新上下文
                string::utf8(b"new_context"),  // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The updated context tag"),  // 描述：更新后的上下文标签
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：是否长期
                string::utf8(b"is_long_term"),  // 参数名称
                string::utf8(b"bool"),       // 类型描述
                string::utf8(b"Whether to store as a permanent memory"),  // 描述：是否作为永久记忆存储
                true,                        // 是否必需
            ),
        ];

        vector::push_back(&mut descriptions, action::new_action_description(  // 添加更新自己动作描述
            string::utf8(ACTION_NAME_UPDATE_SELF),  // 动作名称
            string::utf8(b"Update a memory about yourself"),  // 描述：更新关于自己的记忆
            update_self_args,                // 参数列表
            string::utf8(UPDATE_SELF_EXAMPLE),  // 参数示例
            string::utf8(b"Use this to modify your existing memories about yourself"),  // 使用提示：用于修改关于自己的现有记忆
            string::utf8(b"Set content to '[deleted]' to mark a memory for deletion"),  // 约束：将内容设为 '[deleted]' 以标记记忆删除
        ));

        // 注册更新用户动作（更新 AI 关于用户的记忆）
        let update_user_args = vector[       // 创建更新用户动作参数列表
            action::new_action_argument(     // 参数：索引
                string::utf8(b"index"),      // 参数名称
                string::utf8(b"u64"),        // 类型描述
                string::utf8(b"The index of the user memory to update"),  // 描述：要更新的用户记忆索引
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：新内容
                string::utf8(b"new_content"),  // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The updated content"),  // 描述：更新后的内容
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：新上下文
                string::utf8(b"new_context"),  // 参数名称
                string::utf8(b"string"),     // 类型描述
                string::utf8(b"The updated context tag"),  // 描述：更新后的上下文标签
                true,                        // 是否必需
            ),
            action::new_action_argument(     // 参数：是否长期
                string::utf8(b"is_long_term"),  // 参数名称
                string::utf8(b"bool"),       // 类型描述
                string::utf8(b"Whether to store as a permanent memory"),  // 描述：是否作为永久记忆存储
                true,                        // 是否必需
            ),
        ];

        vector::push_back(&mut descriptions, action::new_action_description(  // 添加更新用户动作描述
            string::utf8(ACTION_NAME_UPDATE_USER),  // 动作名称
            string::utf8(b"Update a memory about the current user"),  // 描述：更新关于当前用户的记忆
            update_user_args,                // 参数列表
            string::utf8(UPDATE_USER_EXAMPLE),  // 参数示例
            string::utf8(b"Use this to modify your existing memories about the user"),  // 使用提示：用于修改关于用户的现有记忆
            string::utf8(b"Set content to '[deleted]' to mark a memory for deletion"),  // 约束：将内容设为 '[deleted]' 以标记记忆删除
        ));
        descriptions                         // 返回动作描述列表
    }

    /// 执行动作（已废弃）
    public fun execute(_agent: &mut Object<Agent>, _action_name: String, _args_json: String) {
        // TODO: 已废弃，需移除
    }

    /// 执行动作（版本2，已废弃）
    public fun execute_v2(_agent: &mut Object<Agent>, _agent_input: &AgentInputInfo, _action_name: String, _args_json: String) {
        abort 0                              // 终止执行
    }

    /// 执行记忆动作
    /// 参数：
    /// - agent: 可变的代理对象
    /// - agent_input: 代理输入信息（V2）
    /// - action_name: 动作名称
    /// - args_json: 动作参数（JSON 格式）
    /// 返回：执行结果（成功与否）
    public fun execute_v3(agent: &mut Object<Agent>, agent_input: &AgentInputInfoV2, action_name: String, args_json: String) : Result<bool, String> {
        let agent_address = agent::get_agent_address(agent);  // 获取代理地址
        let store = agent::borrow_mut_memory_store(agent);  // 借用可变的记忆存储
        
        if (action_name == string::utf8(ACTION_NAME_REMEMBER_SELF)) {  // 如果是记住自己动作
            // 添加关于自己的记忆
            let args_opt = json::from_json_option<RememberSelfArgs>(string::into_bytes(args_json));  // 从 JSON 解析参数
            if (!option::is_some(&args_opt)) {  // 如果参数解析失败
                return err_str(b"Invalid arguments for remember_self action")  // 返回错误：无效参数
            };
            let args = option::destroy_some(args_opt);  // 提取解析出的参数
            memory::add_memory(store, agent_address, args.content, args.context, args.is_long_term);  // 添加记忆
            ok(true)  // 返回成功结果
        } 
        else if (action_name == string::utf8(ACTION_NAME_REMEMBER_USER)) {  // 如果是记住用户动作
            // 添加关于当前用户的记忆
            let args_opt = json::from_json_option<RememberUserArgs>(string::into_bytes(args_json));  // 从 JSON 解析参数
            if (!option::is_some(&args_opt)) {  // 如果参数解析失败
                return err_str(b"Invalid arguments for remember_user action")  // 返回错误：无效参数
            };
            let args = option::destroy_some(args_opt);  // 提取解析出的参数
            let current_user = agent_input::get_sender_from_info_v2(agent_input);  // 获取当前用户地址
            memory::add_memory(store, current_user, args.content, args.context, args.is_long_term);  // 添加记忆
            ok(true)  // 返回成功结果
        }
        else if (action_name == string::utf8(ACTION_NAME_UPDATE_SELF)) {  // 如果是更新自己动作
            // 更新关于自己的记忆
            let args_opt = json::from_json_option<UpdateSelfMemoryArgs>(string::into_bytes(args_json));  // 从 JSON 解析参数
            if (!option::is_some(&args_opt)) {  // 如果参数解析失败
                return err_str(b"Invalid arguments for update_self action")  // 返回错误：无效参数
            };
            let args = option::destroy_some(args_opt);  // 提取解析出的参数
            memory::update_memory(           // 更新记忆
                store,
                agent_address,
                args.index,
                args.new_content,
                option::some(args.new_context),
                args.is_long_term
            );
            ok(true)  // 返回成功结果
        }
        else if (action_name == string::utf8(ACTION_NAME_UPDATE_USER)) {  // 如果是更新用户动作
            // 更新关于当前用户的记忆
            let args_opt = json::from_json_option<UpdateUserMemoryArgs>(string::into_bytes(args_json));  // 从 JSON 解析参数
            if (!option::is_some(&args_opt)) {  // 如果参数解析失败
                return err_str(b"Invalid arguments for update_user action")  // 返回错误：无效参数
            };
            let args = option::destroy_some(args_opt);  // 提取解析出的参数
            let current_user = agent_input::get_sender_from_info_v2(agent_input);  // 获取当前用户地址
            memory::update_memory(           // 更新记忆
                store,
                current_user,
                args.index,
                args.new_content,
                option::some(args.new_context),
                args.is_long_term
            );
            ok(true)  // 返回成功结果
        }
        else if (action_name == string::utf8(ACTION_NAME_NONE)) {  // 如果是无记忆动作
            // 此动作仅为标记，无需实际操作
            let none_args = json::from_json_option<NoneArgs>(string::into_bytes(args_json));  // 从 JSON 解析参数
            
            if (!option::is_some(&none_args)) {  // 如果参数解析失败
                return err_str(b"Invalid arguments for none action")  // 返回错误：无效参数
            };

            // 无需处理参数，仅验证
            let none_args = option::destroy_some(none_args);  // 提取解析出的参数
            if (option::is_some(&none_args.reason)) {  // 如果有理由
                let _reason = option::destroy_some(none_args.reason);  // 提取理由
                // std::debug::print(_reason);  // 注释掉的调试打印
            };
            ok(false)  // 返回成功结果（无操作）
        }
        else {
            err_str(b"Unsupported action")  // 返回错误：不支持的动作
        }
    }

    /// 测试记忆动作
    #[test]
    fun test_memory_actions() {
        use std::vector;
        use nuwa_framework::agent;
        use nuwa_framework::agent_input;
        use nuwa_framework::memory;
        use moveos_std::result;

        nuwa_framework::character_registry::init_for_test();  // 初始化测试角色注册表
        action::init_for_test();  // 初始化测试动作模块
        
        let (agent_obj, cap) = agent::create_test_agent();  // 创建测试代理
        let agent_address = agent::get_agent_address(agent_obj);  // 获取代理地址
        let test_addr = @0x42;  // 测试地址
    
        let agent_input_info = agent_input::new_agent_input_info_for_test(  // 创建测试代理输入信息
            test_addr,
            string::utf8(b"{}")
        );
        
        // 测试记住自己动作
        let remember_self_json = string::utf8(b"{\"content\":\"I enjoy helping with technical explanations\",\"context\":\"personal\",\"is_long_term\":true}");
        execute_v3(agent_obj, &agent_input_info, string::utf8(ACTION_NAME_REMEMBER_SELF), remember_self_json);

        // 测试记住用户动作
        let remember_user_json = string::utf8(b"{\"content\":\"User likes detailed explanations\",\"context\":\"preference\",\"is_long_term\":true}");
        execute_v3(agent_obj, &agent_input_info, string::utf8(ACTION_NAME_REMEMBER_USER), remember_user_json);
        
        let store = agent::borrow_memory_store(agent_obj);  // 借用记忆存储
       
        let self_memories = memory::get_context_memories(store, agent_address);  // 获取代理的记忆
        assert!(vector::length(&self_memories) == 1, 1);  // 断言：记忆数量为 1
        let self_memory = vector::borrow(&self_memories, 0);  // 借用第一条记忆
        assert!(memory::get_content(self_memory) == string::utf8(b"I enjoy helping with technical explanations"), 2);  // 断言：内容正确
        
        // 验证用户记忆
        let user_memories = memory::get_context_memories(store, test_addr);  // 获取用户的记忆
        assert!(vector::length(&user_memories) == 1, 3);  // 断言：记忆数量为 1
        let user_memory = vector::borrow(&user_memories, 0);  // 借用第一条记忆
        assert!(memory::get_content(user_memory) == string::utf8(b"User likes detailed explanations"), 4);  // 断言：内容正确
        
        // 测试更新自己动作
        let update_self_json = string::utf8(b"{\"index\":0,\"new_content\":\"I find I'm most effective when providing code examples\",\"new_context\":\"personal\",\"is_long_term\":true}");
        let result = execute_v3(agent_obj, &agent_input_info, string::utf8(ACTION_NAME_UPDATE_SELF), update_self_json);
        assert!(result::is_ok(&result), 5);  // 断言：执行成功
        // 测试更新用户动作
        let update_user_json = string::utf8(b"{\"index\":0,\"new_content\":\"User now prefers concise explanations\",\"new_context\":\"preference\",\"is_long_term\":true}");
        let result = execute_v3(agent_obj, &agent_input_info, string::utf8(ACTION_NAME_UPDATE_USER), update_user_json);
        assert!(result::is_ok(&result), 6);  // 断言：执行成功
        
        store = agent::borrow_memory_store(agent_obj);  // 再次借用记忆存储
        self_memories = memory::get_context_memories(store, agent_address);  // 获取更新后的代理记忆
        let updated_self_memory = vector::borrow(&self_memories, 0);  // 借用第一条记忆
        assert!(memory::get_content(updated_self_memory) == string::utf8(b"I find I'm most effective when providing code examples"), 5);  // 断言：更新内容正确
        
        user_memories = memory::get_context_memories(store, test_addr);  // 获取更新后的用户记忆
        let updated_user_memory = vector::borrow(&user_memories, 0);  // 借用第一条记忆
        assert!(memory::get_content(updated_user_memory) == string::utf8(b"User now prefers concise explanations"), 6);  // 断言：更新内容正确
        
        agent::destroy_agent_cap(cap);  // 销毁代理能力
    }

    /// 测试记忆动作示例
    #[test]
    fun test_memory_action_examples() {
        // 测试记住自己示例
        let self_args = json::from_json<RememberSelfArgs>(REMEMBER_SELF_EXAMPLE);  // 从 JSON 示例解析参数
        assert!(self_args.content == string::utf8(b"I find that I connect well with users who share personal stories"), 1);  // 断言：内容正确
        assert!(self_args.context == string::utf8(b"personal"), 2);  // 断言：上下文正确
        assert!(self_args.is_long_term == true, 3);  // 断言：是否长期正确
        assert!(memory::is_standard_context(&self_args.context), 4);  // 断言：上下文有效

        // 测试记住用户示例
        let user_args = json::from_json<RememberUserArgs>(REMEMBER_USER_EXAMPLE);  // 从 JSON 示例解析参数
        assert!(user_args.content == string::utf8(b"User prefers detailed technical explanations"), 5);  // 断言：内容正确
        assert!(user_args.context == string::utf8(b"preference"), 6);  // 断言：上下文正确
        assert!(user_args.is_long_term == true, 7);  // 断言：是否长期正确
        assert!(memory::is_standard_context(&user_args.context), 8);  // 断言：上下文有效

        // 测试更新自己示例
        let update_self_args = json::from_json<UpdateSelfMemoryArgs>(UPDATE_SELF_EXAMPLE);  // 从 JSON 示例解析参数
        assert!(update_self_args.index == 2, 9);  // 断言：索引正确
        assert!(update_self_args.new_content == string::utf8(b"I've noticed I'm more effective when I ask clarifying questions"), 10);  // 断言：新内容正确
        assert!(update_self_args.new_context == string::utf8(b"personal"), 11);  // 断言：新上下文正确
        assert!(update_self_args.is_long_term == true, 12);  // 断言：是否长期正确

        // 测试更新用户示例
        let update_user_args = json::from_json<UpdateUserMemoryArgs>(UPDATE_USER_EXAMPLE);  // 从 JSON 示例解析参数
        assert!(update_user_args.index == 3, 13);  // 断言：索引正确
        assert!(update_user_args.new_content == string::utf8(b"User now prefers concise explanations with code examples"), 14);  // 断言：新内容正确
        assert!(update_user_args.new_context == string::utf8(b"preference"), 15);  // 断言：新上下文正确
        assert!(update_user_args.is_long_term == true, 16);  // 断言：是否长期正确
    }

    // 为 memory::none 动作添加新测试
    #[test]
    fun test_memory_none_action() {
        let _none_args = json::from_json<NoneArgs>(NONE_EXAMPLE);  // 从 JSON 示例解析参数（仅验证解析）
    }
}