module nuwa_framework::string_utils {
    use std::vector;                          // 导入标准库中的向量模块
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use moveos_std::object::{Self, ObjectID}; // 导入 MoveOS 标准库中的对象模块，并引入 ObjectID 类型
    use moveos_std::json;                     // 导入 MoveOS 标准库中的 JSON 模块
    
    friend nuwa_framework::action_dispatcher; // 声明 action_dispatcher 模块为友元模块
    friend nuwa_framework::response_action;   // 声明 response_action 模块为友元模块
    friend nuwa_framework::message;           // 声明 message 模块为友元模块
    friend nuwa_framework::agent_state;       // 声明 agent_state 模块为友元模块
    friend nuwa_framework::channel_provider;  // 声明 channel_provider 模块为友元模块
    friend nuwa_framework::state_providers;   // 声明 state_providers 模块为友元模块
    friend nuwa_framework::balance_provider;  // 声明 balance_provider 模块为友元模块
    friend nuwa_framework::task_action;       // 声明 task_action 模块为友元模块
    friend nuwa_framework::task_spec;         // 声明 task_spec 模块为友元模块
    
    //TODO migrate to std::string::starts_with  // 注释：待迁移到标准库的 starts_with 函数
    public(friend) fun starts_with(haystack_str: &String, needle: &vector<u8>): bool {  // 定义友元函数：检查字符串是否以指定字节向量开头
        let haystack = string::bytes(haystack_str);  // 将字符串转换为字节向量（待查找的内容）
        let haystack_len = vector::length(haystack);  // 获取待查找字节向量的长度
        let needle_len = vector::length(needle);      // 获取查找目标（前缀）的长度

        if (needle_len > haystack_len) {          // 如果前缀长度大于待查找内容长度
            return false                          // 返回 false（不可能匹配）
        };

        let i = 0;                                // 初始化索引
        while (i < needle_len) {                  // 遍历前缀的每个字节
            if (vector::borrow(haystack, i) != vector::borrow(needle, i)) {  // 如果当前字节不匹配
                return false                      // 返回 false
            };
            i = i + 1;                            // 索引递增
        };

        true                                      // 所有字节匹配，返回 true
    }

    //TODO migrate to std::string or moveos_std::string_utils  // 注释：待迁移到标准库或 MoveOS 的字符串工具模块
    /// Split string by delimiter               // 注释：按分隔符分割字符串
    public(friend) fun split(s: &String, delimiter: &String): vector<String> {  // 定义友元函数：按分隔符分割字符串
        let result = vector::empty<String>();     // 初始化结果向量，用于存储分割后的字符串
        let bytes = string::bytes(s);             // 将输入字符串转换为字节向量
        let delimiter_bytes = string::bytes(delimiter);  // 将分隔符字符串转换为字节向量
        let delimiter_len = vector::length(delimiter_bytes);  // 获取分隔符的长度
        let len = vector::length(bytes);          // 获取输入字符串字节向量的长度
        
        let start = 0;                            // 初始化子字符串的起始位置
        let i = 0;                                // 初始化遍历索引
        while (i <= len) {                        // 遍历字节向量（包括末尾）
            if (i == len || is_substr_at(bytes, delimiter_bytes, i)) {  // 如果到达末尾或当前位置有分隔符
                if (i >= start) {                 // 如果当前段有内容（起始位置小于等于当前位置）
                    let part = get_substr(bytes, start, i);  // 提取子字符串
                    vector::push_back(&mut result, string::utf8(part));  // 将子字符串加入结果向量
                };
                if (i == len) break;              // 如果到达末尾，退出循环
                start = i + delimiter_len;        // 更新起始位置为分隔符后的位置
                i = start;                        // 更新索引到新的起始位置
            } else {
                i = i + 1;                        // 索引递增
            };
        };
        result                                    // 返回分割后的字符串向量
    }

    /// Check if the substring appears at position i in bytes  // 注释：检查子字符串是否出现在字节向量的指定位置
    fun is_substr_at(bytes: &vector<u8>, sub: &vector<u8>, i: u64): bool {  // 定义函数：检查子字符串是否出现在指定位置
        let sub_len = vector::length(sub);        // 获取子字符串的长度
        let len = vector::length(bytes);          // 获取主字节向量的长度
        if (i + sub_len > len) return false;      // 如果子字符串超出主字符串范围，返回 false
        let j = 0;                                // 初始化子字符串索引
        while (j < sub_len) {                     // 遍历子字符串的每个字节
            if (*vector::borrow(bytes, i + j) != *vector::borrow(sub, j)) {  // 如果字节不匹配
                return false                      // 返回 false
            };
            j = j + 1;                            // 子字符串索引递增
        };
        true                                      // 所有字节匹配，返回 true
    }

    /// Get substring from start to end (exclusive)  // 注释：获取从 start 到 end（不包含）的子字符串
    public(friend) fun get_substr(bytes: &vector<u8>, start: u64, end: u64): vector<u8> {  // 定义友元函数：提取字节向量的子字符串
        let result = vector::empty();             // 初始化结果字节向量
        let i = start;                            // 从起始位置开始
        while (i < end) {                         // 遍历到结束位置（不包含）
            vector::push_back(&mut result, *vector::borrow(bytes, i));  // 将当前字节加入结果
            i = i + 1;                            // 索引递增
        };
        result                                    // 返回提取的子字符串字节向量
    }

    public(friend) fun channel_id_to_string(channel_id: ObjectID): String {  // 定义友元函数：将通道 ID 转换为字符串
        object::to_string(&channel_id)            // 调用对象模块的 to_string 函数将 ObjectID 转换为字符串
    }

    public(friend) fun string_to_channel_id(channel_id_str: String): ObjectID {  // 定义友元函数：将字符串转换为通道 ID
        object::from_string(&channel_id_str)      // 调用对象模块的 from_string 函数将字符串转换为 ObjectID
    }

    public(friend) fun trim(s: &String): String {  // 定义友元函数：去除字符串首尾的空格
        let bytes = string::bytes(s);             // 将字符串转换为字节向量
        let len = vector::length(bytes);          // 获取字节向量的长度
        let start = find_first_non_space(bytes, 0, len);  // 查找第一个非空格字符的位置
        let end = find_last_non_space(bytes, 0, len);  // 查找最后一个非空格字符的位置
        if (start >= end) {                       // 如果起始位置大于等于结束位置（无有效内容）
            return string::utf8(b"")              // 返回空字符串
        };
        let result = get_substr(bytes, start, end + 1);  // 提取从 start 到 end+1 的子字符串
        string::utf8(result)                      // 将字节向量转换为 UTF-8 字符串并返回
    }

    const SPACE_CHAR :u8 = 32u8;                  // 定义常量：空格字符的 ASCII 码（32）

    fun find_first_non_space(bytes: &vector<u8>, start: u64, end: u64): u64 {  // 定义函数：查找第一个非空格字符的位置
        let i = start;                            // 从起始位置开始
        while (i < end) {                         // 遍历到结束位置
            if (*vector::borrow(bytes, i) != SPACE_CHAR) {  // 如果当前字符不是空格
                return i                          // 返回当前索引
            };
            i = i + 1;                            // 索引递增
        };
        end                                       // 如果全是空格，返回结束位置
    }
    
    fun find_last_non_space(bytes: &vector<u8>, start: u64, end: u64): u64 {  // 定义函数：查找最后一个非空格字符的位置
        let i = end;                              // 从结束位置开始
        while (i > start) {                       // 向前遍历到起始位置
            if (*vector::borrow(bytes, i - 1) != SPACE_CHAR) {  // 如果前一个字符不是空格
                return i - 1                      // 返回前一个字符的索引
            };
            i = i - 1;                            // 索引递减
        };
        start                                     // 如果全是空格，返回起始位置
    }

    public(friend) fun strip_prefix(s: String, prefix: &vector<u8>): String {  // 定义友元函数：去除字符串的前缀
        let bytes = string::bytes(&s);            // 将字符串转换为字节向量
        let prefix_len = vector::length(prefix);  // 获取前缀的长度
        let len = vector::length(bytes);          // 获取字符串字节向量的长度
        if (prefix_len > len) {                   // 如果前缀长度大于字符串长度
            return s                              // 返回原字符串（无法去除）
        };
        let i = 0;                                // 初始化索引
        while (i < prefix_len) {                  // 遍历前缀的每个字节
            if (*vector::borrow(bytes, i) != *vector::borrow(prefix, i)) {  // 如果字节不匹配
                return s                          // 返回原字符串（前缀不匹配）
            };
            i = i + 1;                            // 索引递增
        };
        string::utf8(get_substr(bytes, prefix_len, len))  // 去除前缀后返回剩余部分
    }

    // Helper function to format JSON sections  // 注释：辅助函数，用于格式化 JSON 部分
    public fun build_json_section<D>(data: &D): String {  // 定义公开函数：构建格式化的 JSON 字符串
        let json_str = string::utf8(json::to_json(data));  // 将数据转换为 JSON 字符串
        // Add proper indentation and line breaks for better readability  // 注释：添加适当的缩进和换行以提高可读性
        let formatted = string::utf8(b"```json\n");  // 初始化格式化字符串，以 "```json" 开头
        string::append(&mut formatted, json_str);    // 追加 JSON 内容
        string::append(&mut formatted, string::utf8(b"\n```\n"));  // 追加结束标记和换行
        formatted                                    // 返回格式化后的字符串
    }

    #[test]
    fun test_trim() {                             // 定义测试函数：测试 trim 函数
        let s = string::utf8(b"  hello, world  ");  // 创建测试字符串，带有首尾空格
        let trimmed = trim(&s);                   // 调用 trim 函数去除首尾空格
        assert!(trimmed == string::utf8(b"hello, world"), 1);  // 断言：确保结果正确

        let s2 = string::utf8(b"  ");             // 创建测试字符串，仅包含空格
        let trimmed2 = trim(&s2);                 // 调用 trim 函数
        assert!(trimmed2 == string::utf8(b""), 2);  // 断言：确保返回空字符串

        let s3 = string::utf8(b"");               // 创建测试字符串，空字符串
        let trimmed3 = trim(&s3);                 // 调用 trim 函数
        assert!(trimmed3 == string::utf8(b""), 3);  // 断言：确保返回空字符串
    }

    #[test]
    fun test_split() {                            // 定义测试函数：测试 split 函数
        let s = string::utf8(b"hello,world,test");  // 创建测试字符串，使用逗号分隔
        let parts = split(&s, &string::utf8(b","));  // 调用 split 函数按逗号分割
        assert!(vector::length(&parts) == 3, 1);  // 断言：确保分割成 3 部分
        assert!(*vector::borrow(&parts, 0) == string::utf8(b"hello"), 2);  // 断言：第一部分是 "hello"
        assert!(*vector::borrow(&parts, 1) == string::utf8(b"world"), 3);  // 断言：第二部分是 "world"
        assert!(*vector::borrow(&parts, 2) == string::utf8(b"test"), 4);   // 断言：第三部分是 "test"

        // Test empty parts                     // 注释：测试空部分的情况
        let s2 = string::utf8(b"a,,b");           // 创建测试字符串，包含连续逗号
        let parts2 = split(&s2, &string::utf8(b","));  // 调用 split 函数按逗号分割
        assert!(vector::length(&parts2) == 3, 5);  // 断言：确保分割成 3 部分
        assert!(*vector::borrow(&parts2, 0) == string::utf8(b"a"), 6);  // 断言：第一部分是 "a"
        assert!(*vector::borrow(&parts2, 1) == string::utf8(b""), 7);   // 断言：第二部分是空字符串
        assert!(*vector::borrow(&parts2, 2) == string::utf8(b"b"), 8);  // 断言：第三部分是 "b"
    }
}