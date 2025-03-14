module nuwa_framework::character {
    use std::string::String;                  // 导入标准库中的字符串模块，并引入 String 类型
    use std::vector;                          // 导入标准库中的向量模块
    use moveos_std::object::{Self, Object};  // 导入 MoveOS 标准库中的对象模块，并引入 Object 类型
    use moveos_std::json;                     // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::signer;                   // 导入 MoveOS 标准库中的签名者模块
    use nuwa_framework::character_registry;   // 导入 nuwa_framework 中的角色注册模块

    const ErrorUsernameAlreadyRegistered: u64 = 1;  // 定义错误码：用户名已被注册

    /// Character represents an AI agent's personality and knowledge  // 注释：Character 表示 AI 代理的个性和知识
    struct Character has key, store {         // 定义角色结构体，具有 key 和 store 能力
        name: String,                         // 角色名称
        username: String,                     // 用户名
        description: String,                  // 角色的系统提示（描述）
        bio: vector<String>,                  // 角色的背景故事和个性（多行文本）
        knowledge: vector<String>,            // 角色的领域知识和能力（多行文本）
    }

    #[data_struct]
    /// Data structure for character creation  // 注释：用于角色创建的数据结构
    struct CharacterData has copy, drop, store {  // 定义角色数据结构体，具有 copy、drop、store 能力
        name: String,                         // 角色名称
        username: String,                     // 用户名
        description: String,                  // 描述
        bio: vector<String>,                  // 简介（多行文本）
        knowledge: vector<String>,            // 知识库（多行文本）
    }

    public fun new_character_data(            // 定义公开函数：创建新的角色数据
        name: String,                         // 角色名称
        username: String,                     // 用户名
        description: String,                  // 描述
        bio: vector<String>,                  // 简介
        knowledge: vector<String>,            // 知识库
    ): CharacterData {                        // 返回 CharacterData 类型
        CharacterData {                       // 创建并返回 CharacterData 实例
            name,                             // 名称
            username,                         // 用户名
            description,                      // 描述
            bio,                              // 简介
            knowledge,                        // 知识库
        }
    }

    fun new_character(data: CharacterData): Object<Character> {  // 定义函数：创建新的角色对象
        assert!(character_registry::is_username_available(&data.username), ErrorUsernameAlreadyRegistered);  // 断言：确保用户名未被注册，否则抛出错误
        let character = Character {           // 创建 Character 实例
            name: data.name,                  // 名称
            username: data.username,          // 用户名
            description: data.description,    // 描述
            bio: data.bio,                    // 简介
            knowledge: data.knowledge,        // 知识库
        };
        // Every account only has one character  // 注释：每个账户只能有一个角色
        let obj = object::new(character);     // 将角色封装为对象
        let character_id = object::id(&obj);  // 获取角色对象的 ID
        character_registry::register_username(data.username, character_id);  // 在注册表中注册用户名和角色 ID
        obj                                   // 返回角色对象
    }

    fun drop_character(c: Character) {        // 定义函数：销毁角色
        let Character {                       // 解构 Character 实例
            name: _,                          // 忽略名称
            username,                         // 获取用户名
            description: _,                   // 忽略描述
            bio: _,                           // 忽略简介
            knowledge: _,                     // 忽略知识库
        } = c;
        character_registry::unregister_username(username);  // 从注册表中注销用户名
    }

    public fun create_character(data: CharacterData): Object<Character> {  // 定义公开函数：创建角色
        let co = new_character(data);         // 调用 new_character 创建角色对象
        co                                    // 返回角色对象
    }

    public entry fun create_character_from_json(caller: &signer, json: vector<u8>) {  // 定义公开入口函数：从 JSON 创建角色
        let data = json::from_json<CharacterData>(json);  // 从 JSON 字节向量解析出 CharacterData
        let co = create_character(data);      // 创建角色对象
        object::transfer(co, signer::address_of(caller));  // 将角色对象转移给调用者
    }

    public entry fun create_character_entry(caller: &signer, name: String, username: String, description: String) {  // 定义公开入口函数：通过参数创建角色
        let data = new_character_data(name, username, description, vector::empty(), vector::empty());  // 创建角色数据，简介和知识库为空
        let co = create_character(data);      // 创建角色对象
        object::transfer(co, signer::address_of(caller));  // 将角色对象转移给调用者
    }

    public entry fun add_bio(co: &mut Object<Character>, bio: String) {  // 定义公开入口函数：添加简介
        let c = object::borrow_mut(co);       // 借用角色的可变引用
        if (vector::contains(&c.bio, &bio)) {  // 如果简介已包含该内容
            return                            // 直接返回，不重复添加
        };
        vector::push_back(&mut c.bio, bio);   // 将新简介添加到简介向量
    }

    public entry fun add_knowledge(co: &mut Object<Character>, knowledge: String) {  // 定义公开入口函数：添加知识
        let c = object::borrow_mut(co);       // 借用角色的可变引用
        if (vector::contains(&c.knowledge, &knowledge)) {  // 如果知识库已包含该内容
            return                            // 直接返回，不重复添加
        };
        vector::push_back(&mut c.knowledge, knowledge);  // 将新知识添加到知识库向量
    }

    public entry fun destroy_character(co: Object<Character>) {  // 定义公开入口函数：销毁角色
        let c = object::remove(co);           // 从对象中移除角色
        drop_character(c);                    // 调用 drop_character 销毁角色
    }

    public fun get_name(character: &Character): &String {  // 定义公开函数：获取角色名称
        &character.name                       // 返回名称的引用
    }

    public fun get_username(character: &Character): &String {  // 定义公开函数：获取角色用户名
        &character.username                   // 返回用户名的引用
    }

    public fun get_description(character: &Character): &String {  // 定义公开函数：获取角色描述
        &character.description                // 返回描述的引用
    }

    public fun get_bio(character: &Character): &vector<String> {  // 定义公开函数：获取角色简介
        &character.bio                        // 返回简介向量的引用
    }

    public fun get_knowledge(character: &Character): &vector<String> {  // 定义公开函数：获取角色知识库
        &character.knowledge                  // 返回知识库向量的引用
    }

    // Add these functions to allow updating character properties  // 注释：添加这些函数以允许更新角色属性
    public fun update_name(character: &mut Object<Character>, new_name: String) {  // 定义公开函数：更新角色名称
        let c = object::borrow_mut(character);  // 借用角色的可变引用
        c.name = new_name;                    // 更新名称
    }

    public fun update_description(character: &mut Object<Character>, new_description: String) {  // 定义公开函数：更新角色描述
        let c = object::borrow_mut(character);  // 借用角色的可变引用
        c.description = new_description;      // 更新描述
    }

    #[test(caller = @0x42)]
    fun test_character() {                    // 定义测试函数：测试角色功能，指定调用者地址为 @0x42
        use std::string;                      // 在测试中使用标准字符串模块
        nuwa_framework::character_registry::init_for_test();  // 初始化测试用的角色注册表
        // Create test character             // 注释：创建测试角色
        let data = new_character_data(        // 创建测试角色数据
            string::utf8(b"Dobby"),           // 名称：Dobby
            string::utf8(b"dobby"),           // 用户名：dobby
            string::utf8(b"You are Dobby, a helpful and loyal assistant."),  // 描述：你是一个乐于助人且忠诚的助手 Dobby
            vector[string::utf8(b"Dobby is a free assistant who helps because of his enormous heart.")],  // 简介：Dobby 是一个因巨大爱心而乐于助人的自由助手
            vector[string::utf8(b"Creative problem-solving")]  // 知识库：创造性问题解决
        );
        
        let character_obj = create_character(data);  // 创建角色对象
        let character = object::borrow(&character_obj);  // 借用角色引用
        
        // Verify character fields           // 注释：验证角色字段
        assert!(*get_name(character) == string::utf8(b"Dobby"), 1);  // 断言：名称为“Dobby”
        assert!(*get_description(character) == string::utf8(b"You are Dobby, a helpful and loyal assistant."), 2);  // 断言：描述正确
        assert!(vector::length(get_bio(character)) == 1, 3);  // 断言：简介长度为 1
        assert!(vector::length(get_knowledge(character)) == 1, 4);  // 断言：知识库长度为 1
       
        // Test add_bio                     // 注释：测试添加简介
        add_bio(&mut character_obj, string::utf8(b"Dobby excels at programming and system design"));  // 添加简介：Dobby 擅长编程和系统设计
        let character = object::borrow(&character_obj);  // 重新借用角色引用
        assert!(vector::length(get_bio(character)) == 2, 6);  // 断言：简介长度为 2

        // Test add_knowledge               // 注释：测试添加知识
        add_knowledge(&mut character_obj, string::utf8(b"System architecture"));  // 添加知识：系统架构
        let character = object::borrow(&character_obj);  // 重新借用角色引用
        assert!(vector::length(get_knowledge(character)) == 2, 7);  // 断言：知识库长度为 2

        // Clean up                         // 注释：清理
        destroy_character(character_obj);     // 销毁角色对象
    }
}