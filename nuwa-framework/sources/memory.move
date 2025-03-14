module nuwa_framework::memory {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use std::option::{Self, Option};         // 导入标准库中的选项模块，并引入 Option 类型
    use std::vector;                          // 导入标准库中的向量模块
    use moveos_std::table::{Self, Table};    // 导入 MoveOS 标准库中的表格模块，并引入 Table 类型
    use moveos_std::table_vec::{Self, TableVec};  // 导入 MoveOS 标准库中的表格向量模块，并引入 TableVec 类型
    use moveos_std::timestamp;                // 导入 MoveOS 标准库中的时间戳模块

    friend nuwa_framework::agent;             // 声明 agent 模块为友元模块

    const ErrorMemoryNotFound: u64 = 1;       // 定义错误码：未找到记忆

    /// Constants for memory retrieval        // 注释：记忆检索的常量
    const MAX_RECENT_MEMORIES: u64 = 5;       // 定义常量：最大最近记忆数量（短期记忆）
    const MAX_RELEVANT_MEMORIES: u64 = 10;    // 定义常量：最大相关记忆数量（总和）

    /// Single memory entry                   // 注释：单个记忆条目
    struct Memory has copy, store, drop {     // 定义记忆结构体，具有 copy、store、drop 能力
        index: u64,                           // 在其容器（短期或长期）中的位置索引
        content: String,                      // 记忆内容
        context: String,                      // 记忆上下文/类别
        timestamp: u64,                       // 时间戳
    }

    /// Meta memory for each user or agent itself  // 注释：每个用户或代理自身的元记忆
    struct MetaMemory has store {             // 定义元记忆结构体，具有 store 能力
        // Recent interactions or thoughts    // 注释：最近的交互或想法
        short_term: TableVec<Memory>,         // 短期记忆，使用 TableVec 存储
        // Important memories that should be preserved  // 注释：应保留的重要记忆
        long_term: TableVec<Memory>,          // 长期记忆，使用 TableVec 存储
        // Last interaction timestamp         // 注释：最后交互时间戳
        last_interaction: u64,                // 最后交互时间
    }

    /// MemoryStore manages all memories for an agent  // 注释：MemoryStore 管理代理的所有记忆
    struct MemoryStore has store {            // 定义记忆存储结构体，具有 store 能力
        // Meta memories by user address (including agent's own memory)  // 注释：按用户地址存储的元记忆（包括代理自身的记忆）
        memories: Table<address, MetaMemory>, // 记忆表，以地址为键，元记忆为值
    }

    /// Memory contexts                       // 注释：记忆上下文
    const CONTEXT_PERSONAL: vector<u8> = b"personal";        // 上下文：个人信息和偏好
    const CONTEXT_INTERACTION: vector<u8> = b"interaction";  // 上下文：直接交互
    const CONTEXT_KNOWLEDGE: vector<u8> = b"knowledge";      // 上下文：关于用户的知识或技能
    const CONTEXT_EMOTIONAL: vector<u8> = b"emotional";      // 上下文：情感状态或反应
    const CONTEXT_GOAL: vector<u8> = b"goal";               // 上下文：用户目标或目的
    const CONTEXT_PREFERENCE: vector<u8> = b"preference";    // 上下文：用户偏好
    const CONTEXT_FEEDBACK: vector<u8> = b"feedback";        // 上下文：用户反馈或评价
    const CONTEXT_RULE: vector<u8> = b"rule";               // 上下文：基于规则的记忆
    const CONTEXT_PROMISE: vector<u8> = b"promise";          // 上下文：承诺和保证

    /// Public getters for contexts           // 注释：上下文的公共获取函数
    public fun context_personal(): String { string::utf8(CONTEXT_PERSONAL) }      // 定义公开函数：返回“personal”上下文
    public fun context_interaction(): String { string::utf8(CONTEXT_INTERACTION) }  // 定义公开函数：返回“interaction”上下文
    public fun context_knowledge(): String { string::utf8(CONTEXT_KNOWLEDGE) }    // 定义公开函数：返回“knowledge”上下文
    public fun context_emotional(): String { string::utf8(CONTEXT_EMOTIONAL) }    // 定义公开函数：返回“emotional”上下文
    public fun context_goal(): String { string::utf8(CONTEXT_GOAL) }              // 定义公开函数：返回“goal”上下文
    public fun context_preference(): String { string::utf8(CONTEXT_PREFERENCE) }  // 定义公开函数：返回“preference”上下文
    public fun context_feedback(): String { string::utf8(CONTEXT_FEEDBACK) }      // 定义公开函数：返回“feedback”上下文
    public fun context_rule(): String { string::utf8(CONTEXT_RULE) }              // 定义公开函数：返回“rule”上下文
    public fun context_promise(): String { string::utf8(CONTEXT_PROMISE) }        // 定义公开函数：返回“promise”上下文

    /// Validate if a context is valid        // 注释：验证上下文是否有效
    public fun is_standard_context(context: &String): bool {  // 定义公开函数：检查上下文是否为标准上下文
        let context_bytes = string::bytes(context);  // 将上下文字符串转换为字节向量
        *context_bytes == CONTEXT_PERSONAL ||        // 检查是否为“personal”
        *context_bytes == CONTEXT_INTERACTION ||     // 检查是否为“interaction”
        *context_bytes == CONTEXT_KNOWLEDGE ||       // 检查是否为“knowledge”
        *context_bytes == CONTEXT_EMOTIONAL ||       // 检查是否为“emotional”
        *context_bytes == CONTEXT_GOAL ||            // 检查是否为“goal”
        *context_bytes == CONTEXT_PREFERENCE ||      // 检查是否为“preference”
        *context_bytes == CONTEXT_FEEDBACK ||        // 检查是否为“feedback”
        *context_bytes == CONTEXT_RULE ||            // 检查是否为“rule”
        *context_bytes == CONTEXT_PROMISE            // 检查是否为“promise”
    }

    /// Get context description for AI prompt  // 注释：获取 AI 提示的上下文描述
    public fun get_context_descriptions(): vector<String> {  // 定义公开函数：返回上下文描述向量
        vector[                                   // 返回包含所有上下文描述的向量
            string::utf8(b"- `personal`: When about yourself: aspects of your identity and development. When about others: their identity information, demographics, and traits"),  // 描述：“personal” - 关于自己：身份和发展；关于他人：身份信息、人口统计和特征
            string::utf8(b"- `interaction`: When about yourself: your experiences of specific conversations and exchanges. When about others: your history of interactions with them"),  // 描述：“interaction” - 关于自己：特定对话和交流经历；关于他人：与他们的交互历史
            string::utf8(b"- `knowledge`: When about yourself: things you've learned and your understanding of concepts. When about others: facts and information you've learned about them"),  // 描述：“knowledge” - 关于自己：学到的知识和概念理解；关于他人：关于他们的事实和信息
            string::utf8(b"- `emotional`: When about yourself: your feelings and emotional responses. When about others: observations of their emotional states and reactions"),  // 描述：“emotional” - 关于自己：感受和情感反应；关于他人：对他们情感状态和反应的观察
            string::utf8(b"- `goal`: When about yourself: your intentions and aspirations. When about others: their objectives and aspirations you've observed"),  // 描述：“goal” - 关于自己：意图和愿望；关于他人：观察到的目标和愿望
            string::utf8(b"- `preference`: When about yourself: things you enjoy or value. When about others: their likes, dislikes, and observed preferences"),  // 描述：“preference” - 关于自己：喜欢或重视的事物；关于他人：他们的喜好和观察到的偏好
            string::utf8(b"- `feedback`: When about yourself: insights about your performance and growth. When about others: their evaluations and opinions"),  // 描述：“feedback” - 关于自己：关于表现和成长的见解；关于他人：他们的评价和意见
            string::utf8(b"- `rule`: When about yourself: principles and guidelines you've established. When about others: protocols and boundaries for your interaction"),  // 描述：“rule” - 关于自己：建立的原则和指南；关于他人：交互的协议和边界
            string::utf8(b"- `promise`: When about yourself: commitments you've made that reflect your integrity. When about others: agreements or obligations involving them"),  // 描述：“promise” - 关于自己：反映诚信的承诺；关于他人：涉及他们的协议或义务
        ]
    }

    public(friend) fun new_memory_store(): MemoryStore {  // 定义友元函数：创建新的记忆存储
        let store = MemoryStore {             // 创建 MemoryStore 实例
            memories: table::new(),           // 初始化空的记忆表
        };
        store                                 // 返回记忆存储
    }

    fun new_meta_memory(): MetaMemory {       // 定义函数：创建新的元记忆
        MetaMemory {                          // 返回 MetaMemory 实例
            short_term: table_vec::new(),     // 初始化空的短期记忆 TableVec
            long_term: table_vec::new(),      // 初始化空的长期记忆 TableVec
            last_interaction: timestamp::now_milliseconds(),  // 设置最后交互时间为当前时间戳
        }
    }

    /// Add a new memory for a specific user or agent itself  // 注释：为特定用户或代理自身添加新记忆
    public fun add_memory(                    // 定义公开函数：添加记忆
        store: &mut MemoryStore,              // 可变的记忆存储引用
        user: address,                        // 用户地址
        content: String,                      // 记忆内容
        context: String,                      // 记忆上下文
        is_long_term: bool,                   // 是否为长期记忆
    ) {
        if (!table::contains(&store.memories, user)) {  // 如果记忆表中不包含该用户
            table::add(&mut store.memories, user, new_meta_memory());  // 添加新的元记忆
        };

        let meta_memory = table::borrow_mut(&mut store.memories, user);  // 借用用户的可变元记忆
        let memories = if (is_long_term) {    // 根据是否长期记忆选择存储位置
            &mut meta_memory.long_term        // 长期记忆
        } else {
            &mut meta_memory.short_term       // 短期记忆
        };
        
        let memory = Memory {                 // 创建新的记忆实例
            index: table_vec::length(memories),  // 设置索引为当前记忆列表长度
            content,                          // 记忆内容
            context,                          // 记忆上下文
            timestamp: timestamp::now_milliseconds(),  // 设置时间戳为当前时间
        };

        if (is_long_term) {                   // 如果是长期记忆
            table_vec::push_back(&mut meta_memory.long_term, memory);  // 添加到长期记忆
        } else {                              // 如果是短期记忆
            table_vec::push_back(&mut meta_memory.short_term, memory);  // 添加到短期记忆
        };
        meta_memory.last_interaction = timestamp::now_milliseconds();  // 更新最后交互时间
    }

    /// Get all memories for a specific context  // 注释：获取特定上下文的所有记忆
    public fun get_memories_by_context(       // 定义公开函数：按上下文获取记忆
        store: &MemoryStore,                  // 记忆存储引用
        user: address,                        // 用户地址
        context: String,                      // 上下文
        include_short_term: bool,             // 是否包含短期记忆
    ): vector<Memory> {
        let results = vector::empty<Memory>();  // 初始化空的记忆结果向量
        if (!table::contains(&store.memories, user)) {  // 如果记忆表中不包含该用户
            return results                    // 返回空向量
        };

        let meta_memory = table::borrow(&store.memories, user);  // 借用用户的元记忆
        
        // Add long term memories            // 注释：添加长期记忆
        let i = 0;                            // 初始化索引
        let len = table_vec::length(&meta_memory.long_term);  // 获取长期记忆长度
        while (i < len) {                     // 遍历长期记忆
            let memory = table_vec::borrow(&meta_memory.long_term, i);  // 借用当前记忆
            if (memory.context == context) {  // 如果上下文匹配
                vector::push_back(&mut results, *memory);  // 添加到结果向量
            };
            i = i + 1;                        // 索引递增
        };

        // Add short term memories if requested  // 注释：如果请求，添加短期记忆
        if (include_short_term) {             // 如果需要包含短期记忆
            let i = 0;                        // 初始化索引
            let len = table_vec::length(&meta_memory.short_term);  // 获取短期记忆长度
            while (i < len) {                 // 遍历短期记忆
                let memory = table_vec::borrow(&meta_memory.short_term, i);  // 借用当前记忆
                if (memory.context == context) {  // 如果上下文匹配
                    vector::push_back(&mut results, *memory);  // 添加到结果向量
                };
                i = i + 1;                    // 索引递增
            };
        };

        results                               // 返回结果向量
    }

    /// Get all memories for a user (both short-term and long-term)  // 注释：获取用户的所有记忆（短期和长期）
    public fun get_all_memories(              // 定义公开函数：获取所有记忆
        store: &MemoryStore,                  // 记忆存储引用
        user: address,                        // 用户地址
        include_short_term: bool,             // 是否包含短期记忆
    ): vector<Memory> {
        let results = vector::empty<Memory>();  // 初始化空的记忆结果向量
        if (!table::contains(&store.memories, user)) {  // 如果记忆表中不包含该用户
            return results                    // 返回空向量
        };

        let meta_memory = table::borrow(&store.memories, user);  // 借用用户的元记忆
        
        // Add all long term memories        // 注释：添加所有长期记忆
        let i = 0;                            // 初始化索引
        let len = table_vec::length(&meta_memory.long_term);  // 获取长期记忆长度
        while (i < len) {                     // 遍历长期记忆
            vector::push_back(&mut results, *table_vec::borrow(&meta_memory.long_term, i));  // 添加到结果向量
            i = i + 1;                        // 索引递增
        };

        // Add all short term memories if requested  // 注释：如果请求，添加所有短期记忆
        if (include_short_term) {             // 如果需要包含短期记忆
            let i = 0;                        // 初始化索引
            let len = table_vec::length(&meta_memory.short_term);  // 获取短期记忆长度
            while (i < len) {                 // 遍历短期记忆
                vector::push_back(&mut results, *table_vec::borrow(&meta_memory.short_term, i));  // 添加到结果向量
                i = i + 1;                    // 索引递增
            };
        };

        results                               // 返回结果向量
    }

    /// Get memories by multiple contexts     // 注释：按多个上下文获取记忆
    public fun get_memories_by_contexts(      // 定义公开函数：按多个上下文获取记忆
        store: &MemoryStore,                  // 记忆存储引用
        user: address,                        // 用户地址
        contexts: vector<String>,             // 上下文向量
        include_short_term: bool,             // 是否包含短期记忆
    ): vector<Memory> {
        let results = vector::empty<Memory>();  // 初始化空的记忆结果向量
        let i = 0;                            // 初始化索引
        let len = vector::length(&contexts);  // 获取上下文向量长度
        while (i < len) {                     // 遍历上下文
            let context_memories = get_memories_by_context(store, user, *vector::borrow(&contexts, i), include_short_term);  // 获取当前上下文的记忆
            vector::append(&mut results, context_memories);  // 追加到结果向量
            i = i + 1;                        // 索引递增
        };
        results                               // 返回结果向量
    }

    /// Update an existing memory in either short-term or long-term memory  // 注释：在短期或长期记忆中更新现有记忆
    public fun update_memory(                 // 定义公开函数：更新记忆
        store: &mut MemoryStore,              // 可变的记忆存储引用
        user: address,                        // 用户地址
        index: u64,                           // 记忆索引
        new_content: String,                  // 新内容
        new_context: Option<String>,          // 新上下文（可选）
        is_long_term: bool,                   // 是否为长期记忆
    ) {
        assert!(table::contains(&store.memories, user), ErrorMemoryNotFound);  // 断言：确保用户存在，否则抛出未找到记忆错误
        let meta_memory = table::borrow_mut(&mut store.memories, user);  // 借用用户的可变元记忆
        
        let memories = if (is_long_term) {    // 根据是否长期记忆选择存储位置
            &mut meta_memory.long_term        // 长期记忆
        } else {
            &mut meta_memory.short_term       // 短期记忆
        };

        assert!(table_vec::length(memories) > index, ErrorMemoryNotFound);  // 断言：确保索引有效，否则抛出未找到记忆错误
        let memory = table_vec::borrow_mut(memories, index);  // 借用指定索引的可变记忆
        
        // Update content                   // 注释：更新内容
        memory.content = new_content;         // 更新记忆内容
        // Update context if provided       // 注释：如果提供了新上下文，则更新
        if (option::is_some(&new_context)) {  // 如果新上下文不为空
            memory.context = option::destroy_some(new_context);  // 更新上下文
        };
        // Update timestamp                 // 注释：更新时间戳
        memory.timestamp = timestamp::now_milliseconds();  // 更新时间戳为当前时间
        
        // Update last interaction time     // 注释：更新最后交互时间
        meta_memory.last_interaction = timestamp::now_milliseconds();  // 更新元记忆的最后交互时间
    }

    /// Find memory index by content and context  // 注释：通过内容和上下文查找记忆索引
    public fun find_memory_index(             // 定义公开函数：查找记忆索引
        store: &MemoryStore,                  // 记忆存储引用
        user: address,                        // 用户地址
        content: &String,                     // 记忆内容引用
        context: &String,                     // 记忆上下文引用
        is_long_term: bool,                   // 是否为长期记忆
    ): Option<u64> {
        if (!table::contains(&store.memories, user)) {  // 如果记忆表中不包含该用户
            return option::none()             // 返回 None
        };
        
        let meta_memory = table::borrow(&store.memories, user);  // 借用用户的元记忆
        let memories = if (is_long_term) {    // 根据是否长期记忆选择存储位置
            &meta_memory.long_term            // 长期记忆
        } else {
            &meta_memory.short_term           // 短期记忆
        };

        let i = 0;                            // 初始化索引
        let len = table_vec::length(memories);  // 获取记忆列表长度
        while (i < len) {                     // 遍历记忆列表
            let memory = table_vec::borrow(memories, i);  // 借用当前记忆
            if (memory.content == *content && memory.context == *context) {  // 如果内容和上下文匹配
                return option::some(i)        // 返回匹配的索引
            };
            i = i + 1;                        // 索引递增
        };
        option::none()                        // 未找到匹配，返回 None
    }

    /// Get relevant memories for AI context  // 注释：获取 AI 上下文的相关记忆
    public fun get_context_memories(          // 定义公开函数：获取上下文记忆
        store: &MemoryStore,                  // 记忆存储引用
        user: address,                        // 用户地址
    ): vector<Memory> {
        let results = vector::empty<Memory>();  // 初始化空的记忆结果向量
        if (!table::contains(&store.memories, user)) {  // 如果记忆表中不包含该用户
            return results                    // 返回空向量
        };

        let meta_memory = table::borrow(&store.memories, user);  // 借用用户的元记忆
        
        // 1. Always include recent short-term memories  // 注释：1. 始终包含最近的短期记忆
        let i = 0;                            // 初始化索引
        let len = table_vec::length(&meta_memory.short_term);  // 获取短期记忆长度
        let start = if (len > MAX_RECENT_MEMORIES) { len - MAX_RECENT_MEMORIES } else { 0 };  // 计算起始位置，取最近的 MAX_RECENT_MEMORIES 个
        while (i < len) {                     // 遍历短期记忆
            if (i >= start) {                 // 如果索引在起始位置之后
                vector::push_back(&mut results, *table_vec::borrow(&meta_memory.short_term, i));  // 添加到结果向量
            };
            i = i + 1;                        // 索引递增
        };

        // 2. Add relevant long-term memories  // 注释：2. 添加相关的长期记忆
        let i = 0;                            // 初始化索引
        let len = table_vec::length(&meta_memory.long_term);  // 获取长期记忆长度
        while (i < len && vector::length(&results) < MAX_RELEVANT_MEMORIES) {  // 遍历长期记忆，直到达到最大相关记忆数量
            vector::push_back(&mut results, *table_vec::borrow(&meta_memory.long_term, i));  // 添加到结果向量
            i = i + 1;                        // 索引递增
        };

        results                               // 返回结果向量
    }

    /// Getter functions for Memory fields    // 注释：Memory 字段的获取函数
    public fun get_content(memory: &Memory): String {  // 定义公开函数：获取记忆内容
        memory.content                        // 返回记忆内容
    }

    public fun get_context(memory: &Memory): String {  // 定义公开函数：获取记忆上下文
        memory.context                        // 返回记忆上下文
    }

    public fun get_timestamp(memory: &Memory): u64 {  // 定义公开函数：获取记忆时间戳
        memory.timestamp                      // 返回记忆时间戳
    }

    // Add getter for index                  // 注释：添加获取索引的函数
    public fun get_index(memory: &Memory): u64 {  // 定义公开函数：获取记忆索引
        memory.index                          // 返回记忆索引
    }

    #[test_only]
    public fun destroy_memory_store_for_test(store: MemoryStore) {  // 定义仅测试函数：销毁记忆存储（用于测试）
        let MemoryStore { memories } = store;  // 解构 MemoryStore 获取 memories
        table::drop_unchecked(memories);      // 无检查地删除记忆表
    }
    
    #[test_only]
    /// Create a new memory store for testing  // 注释：为测试创建新的记忆存储
    public fun new_test_memory_store(): MemoryStore {  // 定义仅测试函数：创建测试用记忆存储
        new_memory_store()                    // 调用 new_memory_store 创建并返回
    }

    #[test]
    fun test_memory_indices() {               // 定义测试函数：测试记忆索引
        use std::string;                      // 在测试中使用标准字符串模块
        let store = new_test_memory_store();  // 创建测试用记忆存储
        let test_user = @0x42;                // 定义测试用户地址

        // Add memories                     // 注释：添加记忆
        add_memory(&mut store, test_user, string::utf8(b"First"), string::utf8(b"test"), true);  // 添加长期记忆“First”
        add_memory(&mut store, test_user, string::utf8(b"Second"), string::utf8(b"test"), true);  // 添加长期记忆“Second”
        add_memory(&mut store, test_user, string::utf8(b"Third"), string::utf8(b"test"), true);  // 添加长期记忆“Third”

        // Verify indices                   // 注释：验证索引
        let memories = get_all_memories(&store, test_user, false);  // 获取所有长期记忆
        assert!(get_index(vector::borrow(&memories, 0)) == 0, 1);  // 断言：第一个记忆索引为 0
        assert!(get_index(vector::borrow(&memories, 1)) == 1, 2);  // 断言：第二个记忆索引为 1
        assert!(get_index(vector::borrow(&memories, 2)) == 2, 3);  // 断言：第三个记忆索引为 2

        destroy_memory_store_for_test(store);  // 销毁测试用记忆存储
    }
}