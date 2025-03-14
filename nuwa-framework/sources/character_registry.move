module nuwa_framework::character_registry {
    use std::vector;                          // 导入标准库中的向量模块
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use moveos_std::object::{Self, Object, ObjectID};  // 导入 MoveOS 标准库中的对象模块，并引入 Object 和 ObjectID 类型
    use moveos_std::event;                    // 导入 MoveOS 标准库中的事件模块

    friend nuwa_framework::character;         // 声明 character 模块为友元模块

    /// Error codes                          // 注释：错误码
    const ERR_USERNAME_ALREADY_REGISTERED: u64 = 1;  // 错误码：用户名已被注册
    const ERR_USERNAME_NOT_REGISTERED: u64 = 2;      // 错误码：用户名未注册
    const ERR_NOT_OWNER: u64 = 3;                    // 错误码：非拥有者
    const ERR_USERNAME_TOO_SHORT: u64 = 4;           // 错误码：用户名太短
    const ERR_USERNAME_TOO_LONG: u64 = 5;            // 错误码：用户名太长
    const ERR_USERNAME_INVALID_CHAR: u64 = 6;        // 错误码：用户名包含无效字符
    const ERR_USERNAME_EMPTY: u64 = 7;               // 错误码：用户名为空
    const ERR_USERNAME_ONLY_NUMBERS: u64 = 8;        // 错误码：用户名仅包含数字

    // Username constraints                  // 注释：用户名约束
    const MIN_USERNAME_LENGTH: u64 = 4;       // 定义常量：用户名最小长度
    const MAX_USERNAME_LENGTH: u64 = 16;      // 定义常量：用户名最大长度

    /// Events                               // 注释：事件
    struct UsernameRegistered has drop, copy, store {  // 定义用户名注册事件结构体，具有 drop、copy、store 能力
        username: String,                     // 用户名
        character_id: ObjectID,               // 角色 ID
    }

    struct UsernameUnregistered has drop, copy, store {  // 定义用户名注销事件结构体，具有 drop、copy、store 能力
        username: String,                     // 用户名
        character_id: ObjectID,               // 角色 ID
    }

    /// Empty struct for the registry object  // 注释：注册表对象的空结构体
    struct CharacterRegistry has key {        // 定义角色注册表结构体，具有 key 能力
        // The fields will be dynamically added/removed as username registrations  // 注释：字段将根据用户名注册动态添加/移除
    }
    
    /// Initialize the registry              // 注释：初始化注册表
    fun init() {                              // 定义函数：初始化注册表
        let registry = CharacterRegistry {};  // 创建空的 CharacterRegistry 实例
        let registry_obj = object::new_named_object(registry);  // 创建命名对象
        object::to_shared(registry_obj);      // 将对象设置为共享对象
    }

    /// Get the registry object              // 注释：获取注册表对象
    fun borrow_registry_object(): &Object<CharacterRegistry> {  // 定义函数：借用注册表对象
        let registry_obj_id = object::named_object_id<CharacterRegistry>();  // 获取注册表对象的命名 ID
        object::borrow_object<CharacterRegistry>(registry_obj_id)  // 借用并返回注册表对象
    }

    /// Get mutable reference to registry object  // 注释：获取注册表对象的可变引用
    fun borrow_mut_registry_object(): &mut Object<CharacterRegistry> {  // 定义函数：借用可变的注册表对象
        let registry_obj_id = object::named_object_id<CharacterRegistry>();  // 获取注册表对象的命名 ID
        object::borrow_mut_object_shared<CharacterRegistry>(registry_obj_id)  // 借用并返回可变的共享注册表对象
    }

    /// Internal function to check if a username meets all requirements  // 注释：检查用户名是否满足所有要求的内部函数
    /// Returns (is_valid, has_non_number) tuple  // 注释：返回 (是否有效, 是否包含非数字) 元组
    fun check_username_requirements(username: &String): (bool, bool) {  // 定义函数：检查用户名要求
        let bytes = string::bytes(username);  // 将用户名转换为字节向量
        let length = vector::length(bytes);   // 获取用户名长度
        
        // Check basic requirements           // 注释：检查基本要求
        if (length < MIN_USERNAME_LENGTH || length > MAX_USERNAME_LENGTH || length == 0) {  // 如果长度不符合要求或为空
            return (false, false)             // 返回 (无效, 无非数字字符)
        };
        
        // Check for valid characters         // 注释：检查有效字符
        let has_non_number = false;           // 初始化标志：是否包含非数字字符
        let i = 0;                            // 初始化索引
        while (i < length) {                  // 遍历用户名字节
            let char_byte = *vector::borrow(bytes, i);  // 获取当前字符的字节值
            let is_lowercase_letter = char_byte >= 97 && char_byte <= 122;  // 检查是否为小写字母 (a-z)
            let is_uppercase_letter = char_byte >= 65 && char_byte <= 90;   // 检查是否为大写字母 (A-Z)
            let is_digit = char_byte >= 48 && char_byte <= 57;             // 检查是否为数字 (0-9)
            let is_underscore = char_byte == 95;                           // 检查是否为下划线 (_)
            
            if (is_lowercase_letter || is_uppercase_letter || is_underscore) {  // 如果是字母或下划线
                has_non_number = true;        // 设置标志为包含非数字字符
            };
            
            if (!(is_lowercase_letter || is_uppercase_letter || is_digit || is_underscore)) {  // 如果不是有效字符
                return (false, has_non_number)  // 返回 (无效, 当前非数字标志)
            };
            
            i = i + 1;                        // 索引递增
        };
        
        (true, has_non_number)                // 返回 (有效, 是否包含非数字字符)
    }

    /// Validate a username                  // 注释：验证用户名
    public fun validate_username(username: &String) {  // 定义公开函数：验证用户名
        let bytes = string::bytes(username);  // 将用户名转换为字节向量
        let length = vector::length(bytes);   // 获取用户名长度
        
        // Check if username is empty         // 注释：检查用户名是否为空
        assert!(length > 0, ERR_USERNAME_EMPTY);  // 断言：长度大于 0，否则抛出空用户名错误
        
        // Check length constraints           // 注释：检查长度约束
        assert!(length >= MIN_USERNAME_LENGTH, ERR_USERNAME_TOO_SHORT);  // 断言：长度大于等于最小值，否则抛出太短错误
        assert!(length <= MAX_USERNAME_LENGTH, ERR_USERNAME_TOO_LONG);   // 断言：长度小于等于最大值，否则抛出太长错误
        
        let (is_valid, has_non_number) = check_username_requirements(username);  // 检查用户名要求
        
        // Check if all characters are valid  // 注释：检查所有字符是否有效
        assert!(is_valid, ERR_USERNAME_INVALID_CHAR);  // 断言：字符有效，否则抛出无效字符错误
        
        // Username can't be all numbers      // 注释：用户名不能全是数字
        assert!(has_non_number, ERR_USERNAME_ONLY_NUMBERS);  // 断言：包含非数字字符，否则抛出仅数字错误
    }

    /// Register a username for an object    // 注释：为对象注册用户名
    public(friend) fun register_username(username: String, character_id: ObjectID) {  // 定义友元函数：注册用户名
        // Validate the username              // 注释：验证用户名
        validate_username(&username);         // 调用验证函数检查用户名
        
        let registry_mut = borrow_mut_registry_object();  // 借用可变的注册表对象
        
        // Check if username is already registered  // 注释：检查用户名是否已被注册
        assert!(!object::contains_field(registry_mut, username), ERR_USERNAME_ALREADY_REGISTERED);  // 断言：用户名未注册，否则抛出已注册错误
        
        // Register the username by adding a field to the registry object  // 注释：通过向注册表对象添加字段来注册用户名
        object::add_field(registry_mut, username, character_id);  // 添加字段：用户名 -> 角色 ID
        
        // Emit event                        // 注释：触发事件
        event::emit(UsernameRegistered { username, character_id });  // 触发用户名注册事件
    }
    
    /// Unregister a username                // 注释：注销用户名
    public(friend) fun unregister_username(username: String) {  // 定义友元函数：注销用户名
        let registry_mut = borrow_mut_registry_object();  // 借用可变的注册表对象
        
        // Check if username exists           // 注释：检查用户名是否存在
        if (!object::contains_field(registry_mut, username)) {  // 如果用户名不存在
            return                            // 直接返回
        };
        
        // Remove the username                // 注释：移除用户名
        let character_id = object::remove_field(registry_mut, username);  // 从注册表中移除字段并获取角色 ID
        
        // Emit event                        // 注释：触发事件
        event::emit(UsernameUnregistered { username, character_id });  // 触发用户名注销事件
    }
    
    /// Check if a username is available     // 注释：检查用户名是否可用
    public fun is_username_available(username: &String): bool {  // 定义公开函数：检查用户名是否可用
        let registry = borrow_registry_object();  // 借用注册表对象
        !object::contains_field(registry, *username)  // 返回是否未包含该用户名字段（true 表示可用）
    }
    
    /// Get object ID by username            // 注释：通过用户名获取对象 ID
    public fun get_character_id_by_username(username: &String): ObjectID {  // 定义公开函数：通过用户名获取角色 ID
        let registry = borrow_registry_object();  // 借用注册表对象
        assert!(object::contains_field(registry, *username), ERR_USERNAME_NOT_REGISTERED);  // 断言：用户名已注册，否则抛出未注册错误
        *object::borrow_field(registry, *username)  // 借用并返回用户名字段的值（角色 ID）
    }
    
    /// Check if a username is valid (without checking availability)  // 注释：检查用户名是否有效（不检查可用性）
    public fun is_username_valid(username: &String): bool {  // 定义公开函数：检查用户名有效性
        let (is_valid, has_non_number) = check_username_requirements(username);  // 检查用户名要求
        is_valid && has_non_number            // 返回是否有效且包含非数字字符
    }

    #[test_only]
    public fun init_for_test() {              // 定义仅测试函数：为测试初始化注册表
        init();                               // 调用 init 函数初始化
    }

    #[test]
    fun test_registry() {                     // 定义测试函数：测试注册表功能
        use std::string;                      // 在测试中使用标准字符串模块
        
        // Initialize registry               // 注释：初始化注册表
        init_for_test();                      // 为测试初始化注册表
        
        // Create test object ID (using a dummy value for testing)  // 注释：创建测试对象 ID（使用测试用的虚拟值）
        let dummy_object_id = object::named_object_id<CharacterRegistry>();  // 使用现有命名对象 ID 作为测试值
        
        // Test username registration        // 注释：测试用户名注册
        let username = string::utf8(b"testuser");  // 创建测试用户名“testuser”
        assert!(is_username_available(&username), 0);  // 断言：用户名可用
        
        register_username(username, dummy_object_id);  // 注册用户名
        assert!(!is_username_available(&username), 1);  // 断言：用户名不再可用
        
        let stored_id = get_character_id_by_username(&username);  // 获取注册的角色 ID
        assert!(stored_id == dummy_object_id, 2);  // 断言：存储的 ID 与预期一致
        
        // Test unregistering                // 注释：测试注销
        unregister_username(username);        // 注销用户名
        assert!(is_username_available(&username), 3);  // 断言：用户名再次可用
    }
}