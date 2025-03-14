module nuwa_framework::agent {
    use std::string::{Self, String};
    use std::option::{Option};
    use moveos_std::object::{Self, Object, ObjectID};
    use moveos_std::account::{Self, Account};
    use moveos_std::signer;
    use moveos_std::timestamp;
    use nuwa_framework::character::{Self, Character};
    use nuwa_framework::agent_cap::{Self, AgentCap};
    use nuwa_framework::memory::{Self, MemoryStore};
    use nuwa_framework::agent_input::{AgentInput};
    use nuwa_framework::agent_state::{AgentStates};
    use nuwa_framework::agent_info;
    use nuwa_framework::task_spec::{Self, TaskSpecifications, TaskSpecification};
    friend nuwa_framework::memory_action; // 声明 memory_action 模块为友元
    friend nuwa_framework::transfer_action; // 声明 transfer_action 模块为友元
    friend nuwa_framework::action_dispatcher; // 声明 action_dispatcher 模块为友元
    friend nuwa_framework::agent_runner; // 声明 agent_runner 模块为友元

    const TASK_SPEC_PROPERTY_NAME: vector<u8> = b"task_specs"; // 任务规格属性名称常量

    const ErrorDeprecatedFunction: u64 = 1; // 已弃用函数的错误码

    // TODO: 使用新的 agent_runner 模块处理代理运行，此模块仅包含代理数据结构
    /// Agent 代表 Character 的运行实例
    struct Agent has key {
        agent_address: address, // 代理地址
        character: Object<Character>, // 代理对应的角色对象
        account: Object<Account>, // 代理的账户，每个代理有自己的账户
        last_active_timestamp: u64, // 最后活跃时间戳（毫秒）
        memory_store: MemoryStore, // 记忆存储
        model_provider: String, // 模型提供者名称
    }

    // TODO: 移除此结构，未来使用其他方式
    /// 代理信息结构，用于存储代理的基本信息
    struct AgentInfo has copy, drop, store {
        id: ObjectID, // 代理的唯一标识符
        name: String, // 代理名称
        username: String, // 代理用户名
        agent_address: address, // 代理地址
        description: String, // 代理描述
        bio: vector<String>, // 代理简介（多行）
        knowledge: vector<String>, // 代理知识领域
    }

    const AI_GPT4O_MODEL: vector<u8> = b"gpt-4o"; // 默认模型名称常量（GPT-4o）

    /// 创建代理
    /// 参数：
    /// - character: 代理对应的角色对象
    /// 返回：代理能力对象
    public fun create_agent(character: Object<Character>) : Object<AgentCap> {
        let agent_account = account::create_account(); // 创建代理账户
        let agent_signer = account::create_signer_with_account(&mut agent_account); // 创建代理签名者
        // TODO: 提供从账户获取地址的函数
        let agent_address = signer::address_of(&agent_signer); // 获取代理地址
        let agent = Agent {
            agent_address, // 代理地址
            character, // 角色对象
            account: agent_account, // 代理账户
            last_active_timestamp: timestamp::now_milliseconds(), // 当前时间戳
            memory_store: memory::new_memory_store(), // 创建新的记忆存储
            model_provider: string::utf8(AI_GPT4O_MODEL), // 设置默认模型提供者
        };
        // TODO: 向代理账户转移一些 RGas
        // 每个账户仅有一个代理
        let agent_obj = object::new_account_named_object(agent_address, agent); // 创建代理对象
        let agent_obj_id = object::id(&agent_obj); // 获取代理对象 ID
        object::to_shared(agent_obj); // 将代理对象共享
        let agent_cap = agent_cap::new_agent_cap(agent_obj_id); // 创建代理能力对象
        agent_cap // 返回代理能力
    }

    /// 根据 Character 属性生成系统提示（已弃用）
    /// 参数：
    /// - agent: 代理引用
    /// - input: 代理输入
    /// 返回：系统提示字符串
    public fun generate_system_prompt<I: copy + drop>(
        _agent: &Agent,
        _input: AgentInput<I>,
    ): String {
        abort ErrorDeprecatedFunction // 终止执行，已弃用
    }

    /// 根据 Character 属性生成系统提示（版本2，已弃用）
    /// 参数：
    /// - agent: 代理引用
    /// - states: 代理状态
    /// - input: 代理输入
    /// 返回：系统提示字符串
    public fun generate_system_prompt_v2<I: copy + drop>(
        _agent: &Agent,
        _states: AgentStates,
        _input: AgentInput<I>,
    ): String {
        abort ErrorDeprecatedFunction // 终止执行，已弃用
    }

    /// 处理代理输入（已弃用）
    /// 参数：
    /// - caller: 调用者签名者
    /// - agent_obj: 可变的代理对象
    /// - input: 代理输入
    public fun process_input<I: copy + drop>(
        _caller: &signer,
        _agent_obj: &mut Object<Agent>,
        _input: AgentInput<I>,
    ) {
        abort ErrorDeprecatedFunction // 终止执行，已弃用
    }

    /// 处理代理输入（版本2，已弃用）
    /// 参数：
    /// - caller: 调用者签名者
    /// - agent_obj: 可变的代理对象
    /// - states: 代理状态
    /// - input: 代理输入
    public fun process_input_v2<I: copy + drop>(
        _caller: &signer,
        _agent_obj: &mut Object<Agent>,
        _states: AgentStates,
        _input: AgentInput<I>,
    ) {
        abort ErrorDeprecatedFunction // 终止执行，已弃用
    }

    /// 借用可变的代理对象
    /// 参数：
    /// - agent_obj_id: 代理对象 ID
    /// 返回：可变的代理对象引用
    public fun borrow_mut_agent(agent_obj_id: ObjectID): &mut Object<Agent> {
        object::borrow_mut_object_shared(agent_obj_id) // 返回共享对象的可变引用
    }

    /// 根据地址借用可变的代理对象
    /// 参数：
    /// - agent_addr: 代理地址
    /// 返回：可变的代理对象引用
    public fun borrow_mut_agent_by_address(agent_addr: address): &mut Object<Agent> {
        let agent_obj_id = object::account_named_object_id<Agent>(agent_addr); // 获取代理对象 ID
        object::borrow_mut_object_shared(agent_obj_id) // 返回共享对象的可变引用
    }

    /// 获取代理记忆存储的可变引用（友元函数）
    /// 参数：
    /// - agent: 可变的代理对象
    /// 返回：记忆存储的可变引用
    public(friend) fun borrow_mut_memory_store(agent: &mut Object<Agent>): &mut memory::MemoryStore {
        let agent_ref = object::borrow_mut(agent); // 借用代理对象
        &mut agent_ref.memory_store // 返回记忆存储的可变引用
    }

    /// 获取代理记忆存储的不可变引用（友元函数）
    /// 参数：
    /// - agent: 代理对象
    /// 返回：记忆存储的不可变引用
    public(friend) fun borrow_memory_store(agent: &Object<Agent>): &memory::MemoryStore {
        let agent_ref = object::borrow(agent); // 借用代理对象
        &agent_ref.memory_store // 返回记忆存储的不可变引用
    }

    /// 获取代理信息
    /// 参数：
    /// - agent: 代理对象
    /// 返回：代理信息结构
    public fun get_agent_info(agent: &Object<Agent>): AgentInfo {
        let agent_ref = object::borrow(agent); // 借用代理对象
        let character = object::borrow(&agent_ref.character); // 借用角色对象
        AgentInfo {
            id: object::id(agent), // 代理对象 ID
            name: *character::get_name(character), // 角色名称
            username: *character::get_username(character), // 角色用户名
            agent_address: agent_ref.agent_address, // 代理地址
            description: *character::get_description(character), // 角色描述
            bio: *character::get_bio(character), // 角色简介
            knowledge: *character::get_knowledge(character), // 角色知识
        }
    }

    /// 获取代理信息（版本2）
    /// 参数：
    /// - agent: 代理对象
    /// 返回：代理信息结构（新版本）
    public fun get_agent_info_v2(agent: &Object<Agent>): agent_info::AgentInfo {
        let agent_ref = object::borrow(agent); // 借用代理对象
        let character = object::borrow(&agent_ref.character); // 借用角色对象
        agent_info::new_agent_info(
            object::id(agent), // 代理对象 ID
            *character::get_name(character), // 角色名称
            *character::get_username(character), // 角色用户名
            string::utf8(b""), // 空字符串（暂未使用）
            agent_ref.agent_address, // 代理地址
            *character::get_description(character), // 角色描述
            *character::get_bio(character), // 角色简介
            *character::get_knowledge(character), // 角色知识
            agent_ref.model_provider, // 模型提供者
        )
    }

    /// 根据地址获取代理信息
    /// 参数：
    /// - agent_addr: 代理地址
    /// 返回：代理信息结构
    public fun get_agent_info_by_address(agent_addr: address): AgentInfo {
        let agent_obj_id = object::account_named_object_id<Agent>(agent_addr); // 获取代理对象 ID
        let agent_obj = object::borrow_object<Agent>(agent_obj_id); // 借用代理对象
        get_agent_info(agent_obj) // 返回代理信息
    }

    /// 获取代理地址
    /// 参数：
    /// - agent: 代理对象
    /// 返回：代理地址
    public fun get_agent_address(agent: &Object<Agent>): address {
        let agent_ref = object::borrow(agent); // 借用代理对象
        agent_ref.agent_address // 返回代理地址
    }

    /// 获取代理用户名
    /// 参数：
    /// - agent: 代理对象
    /// 返回：代理用户名的引用
    public fun get_agent_username(agent: &Object<Agent>): &String {
        let agent_ref = object::borrow(agent); // 借用代理对象
        let character = object::borrow(&agent_ref.character); // 借用角色对象
        character::get_username(character) // 返回用户名
    }

    /// 获取代理模型提供者
    /// 参数：
    /// - agent: 代理对象
    /// 返回：模型提供者的引用
    public fun get_agent_model_provider(agent: &Object<Agent>): &String {
        let agent_ref = object::borrow(agent); // 借用代理对象
        &agent_ref.model_provider // 返回模型提供者
    }

    /// 销毁代理能力（入口函数）
    /// 参数：
    /// - cap: 代理能力对象
    public entry fun destroy_agent_cap(cap: Object<AgentCap>) {
        // TODO: 记录代理能力被销毁的变量
        agent_cap::destroy_agent_cap(cap); // 销毁代理能力
    }

    /// 检查地址是否为代理账户
    /// 参数：
    /// - addr: 地址
    /// 返回：是否为代理账户
    public fun is_agent_account(addr: address): bool {
        let agent_obj_id = object::account_named_object_id<Agent>(addr); // 获取代理对象 ID
        object::exists_object(agent_obj_id) // 检查对象是否存在
    }

    /// 获取代理自身的个人记忆
    /// 参数：
    /// - agent_obj_id: 代理对象 ID
    /// 返回：代理的个人记忆向量
    public fun get_agent_self_memories(agent_obj_id: ObjectID): vector<memory::Memory> {
        let agent_obj = object::borrow_object<Agent>(agent_obj_id); // 借用代理对象
        let agent_ref = object::borrow(agent_obj); // 借用代理引用
        let memory_store = &agent_ref.memory_store; // 获取记忆存储
        let agent_address = agent_ref.agent_address; // 获取代理地址
        
        // 获取代理自身的记忆（自我反思、个人想法）
        memory::get_all_memories(memory_store, agent_address, true) // 返回所有记忆
    }

    /// 获取代理关于特定用户的记忆
    /// 参数：
    /// - agent_obj_id: 代理对象 ID
    /// - user_address: 用户地址
    /// 返回：关于用户的记忆向量
    public fun get_agent_memories_about_user(agent_obj_id: ObjectID, user_address: address): vector<memory::Memory> {
        let agent_obj = object::borrow_object<Agent>(agent_obj_id); // 借用代理对象
        let agent_ref = object::borrow(agent_obj); // 借用代理引用
        let memory_store = &agent_ref.memory_store; // 获取记忆存储
        
        // 获取关于特定用户的所有记忆
        memory::get_all_memories(memory_store, user_address, true) // 返回所有记忆
    }

    // ============== 可变函数 ==============

    /// 创建代理签名者（友元函数）
    /// 参数：
    /// - agent: 可变的代理对象
    /// 返回：签名者
    public(friend) fun create_agent_signer(agent: &mut Object<Agent>): signer {
        let agent_ref = object::borrow_mut(agent); // 借用可变的代理对象
        account::create_signer_with_account(&mut agent_ref.account) // 创建签名者
    }

    /// 更新代理的最后活跃时间戳（友元函数）
    /// 参数：
    /// - agent: 可变的代理对象
    public(friend) fun update_last_active_timestamp(agent: &mut Object<Agent>) {
        let agent_ref = object::borrow_mut(agent); // 借用可变的代理对象
        agent_ref.last_active_timestamp = timestamp::now_milliseconds(); // 更新时间戳
    }

    /// 更新代理的角色名称和描述
    /// 仅允许拥有代理能力的用户执行
    /// 参数：
    /// - cap: 代理能力对象
    /// - new_name: 新名称
    /// - new_description: 新描述
    public fun update_agent_character(
        cap: &mut Object<AgentCap>,
        new_name: String,
        new_description: String,
    ) {
        let agent_obj_id = agent_cap::get_agent_obj_id(cap); // 获取代理对象 ID
        let agent_obj = borrow_mut_agent(agent_obj_id); // 借用可变的代理对象
        let agent = object::borrow_mut(agent_obj); // 借用代理引用
        
        // 更新角色属性
        character::update_name(&mut agent.character, new_name); // 更新名称
        character::update_description(&mut agent.character, new_description); // 更新描述
    }

    /// 更新代理角色属性的入口函数
    /// 参数：
    /// - cap: 代理能力对象
    /// - new_name: 新名称
    /// - new_description: 新描述
    public entry fun update_agent_character_entry(
        cap: &mut Object<AgentCap>,
        new_name: String,
        new_description: String,
    ) {
        update_agent_character(cap, new_name, new_description); // 调用更新函数
    }

    /// 获取代理任务规格的 JSON 格式
    /// 参数：
    /// - agent_obj: 代理对象
    /// 返回：任务规格的 JSON 字符串
    public fun get_agent_task_specs_json(agent_obj: &Object<Agent>): String {
        let task_specs = get_agent_task_specs(agent_obj); // 获取任务规格
        task_spec::task_specs_to_json(&task_specs) // 转换为 JSON
    }

    /// 获取代理的任务规格
    /// 参数：
    /// - agent_obj: 代理对象
    /// 返回：任务规格对象
    public fun get_agent_task_specs(agent_obj: &Object<Agent>): TaskSpecifications {
        if (object::contains_field(agent_obj, TASK_SPEC_PROPERTY_NAME)) { // 检查字段是否存在
            let task_specs = *object::borrow_field(agent_obj, TASK_SPEC_PROPERTY_NAME); // 借用任务规格
            task_specs // 返回任务规格
        } else {
            task_spec::empty_task_specifications() // 返回空任务规格
        }
    }

    /// 获取代理特定任务的规格
    /// 参数：
    /// - agent_obj: 代理对象
    /// - task_name: 任务名称
    /// 返回：任务规格（可选）
    public fun get_agent_task_spec(agent_obj: &Object<Agent>, task_name: String): Option<TaskSpecification> {
        let task_specs = get_agent_task_specs(agent_obj); // 获取任务规格
        task_spec::get_task_spec_by_name(&task_specs, task_name) // 获取特定任务规格
    }

    /// 更新代理的任务规格
    /// 参数：
    /// - cap: 代理能力对象
    /// - task_specs: 新的任务规格
    public fun update_agent_task_specs(
        cap: &mut Object<AgentCap>,
        task_specs: TaskSpecifications,
    ) {
        let agent_obj_id = agent_cap::get_agent_obj_id(cap); // 获取代理对象 ID
        let agent_obj = borrow_mut_agent(agent_obj_id); // 借用可变的代理对象
        task_spec::validate_task_specifications(&task_specs); // 验证任务规格
        object::upsert_field(agent_obj, TASK_SPEC_PROPERTY_NAME, task_specs); // 更新字段
    }

    /// 更新代理任务规格的入口函数
    /// 参数：
    /// - cap: 代理能力对象
    /// - task_specs_json: 任务规格的 JSON 字符串
    public entry fun update_agent_task_specs_entry(
        cap: &mut Object<AgentCap>,
        task_specs_json: String,
    ) {
        let task_specs = task_spec::task_specs_from_json(task_specs_json); // 从 JSON 解析任务规格
        update_agent_task_specs(cap, task_specs); // 更新任务规格
    }

    /// 为单元测试创建测试代理
    #[test_only]
    public fun create_test_agent(): (&mut Object<Agent>, Object<AgentCap>) {
        use std::string;
        use nuwa_framework::character; 
        
        let char_data = character::new_character_data(
            string::utf8(b"Test Assistant"), // 角色名称
            string::utf8(b"test_assistant"), // 用户名
            string::utf8(b"A helpful test assistant"), // 描述
            vector[string::utf8(b"Friendly"), string::utf8(b"Helpful")], // 简介
            vector[string::utf8(b"General knowledge")] // 知识领域
        );
        let character_obj = character::create_character(char_data); // 创建角色对象
        create_test_agent_with_character(character_obj) // 使用角色创建测试代理
    }

    /// 使用指定角色创建测试代理
    #[test_only]
    public fun create_test_agent_with_character(character: Object<Character>): (&mut Object<Agent>, Object<AgentCap>) {
        use moveos_std::object;
        
        let agent_cap = create_agent(character); // 创建代理
        
        let agent_obj_id = agent_cap::get_agent_obj_id(&agent_cap); // 获取代理对象 ID
        let agent_obj = object::borrow_mut_object_shared<Agent>(agent_obj_id); // 借用可变的代理对象
        (agent_obj, agent_cap) // 返回代理对象和能力
    }

    /// 测试创建测试代理
    #[test]
    fun test_create_test_agent() {
        nuwa_framework::character_registry::init_for_test(); // 初始化测试角色注册表
        let (agent, agent_cap) = create_test_agent(); // 创建测试代理
        assert!(object::is_shared(agent), 1); // 断言代理对象是共享的
        agent_cap::destroy_agent_cap(agent_cap); // 销毁代理能力
    }
}