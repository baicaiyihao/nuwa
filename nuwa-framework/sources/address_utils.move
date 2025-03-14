module nuwa_framework::address_utils {
    use std::string::String;                 // 导入标准库中的字符串模块，并引入 String 类型
    use moveos_std::address;                 // 导入 MoveOS 标准库中的地址模块

    friend nuwa_framework::memory_action;    // 声明 memory_action 模块为友元模块
    friend nuwa_framework::prompt_builder;   // 声明 prompt_builder 模块为友元模块
    friend nuwa_framework::message;          // 声明 message 模块为友元模块

    public(friend) fun parse_address(arg: &String): address {  // 定义友元函数：解析字符串为地址
        address::from_bech32_string(arg)     // 从 Bech32 格式的字符串解析出地址并返回
    }

    // Add helper function to convert address to string  // 注释：添加辅助函数将地址转换为字符串
    public(friend) fun address_to_string(addr: address): String {  // 定义友元函数：将地址转换为字符串
        address::to_bech32_string(addr)      // 将地址转换为 Bech32 格式的字符串并返回
    }

    #[test]
    fun test_parse_address() {               // 定义测试函数：测试地址解析
        let address = moveos_std::tx_context::fresh_address();  // 生成一个新的测试地址
        std::debug::print(&address);         // 打印地址（调试用）
        let address_str = address_to_string(address);  // 将地址转换为字符串
        std::debug::print(&address_str);     // 打印地址字符串（调试用）
        let parsed_address = parse_address(&address_str);  // 从字符串解析回地址
        assert!(address == parsed_address, 1);  // 断言：原始地址与解析后的地址相等
    }
}