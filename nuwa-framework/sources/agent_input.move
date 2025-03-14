module nuwa_framework::agent_input {
    use std::string::{Self, String};         // 导入标准库中的字符串模块，并引入 String 类型
    use moveos_std::json;                    // 导入 MoveOS 标准库中的 JSON 模块
    use moveos_std::decimal_value::{DecimalValue};  // 导入 MoveOS 标准库中的十进制值模块，并引入 DecimalValue 类型
    use moveos_std::copyable_any::{Self, Any};  // 导入 MoveOS 标准库中的可复制任意类型模块，并引入 Any 类型
    
    struct AgentInput<I> has copy, drop, store {  // 定义代理输入结构体，具有 copy、drop、store 能力，泛型参数 I
        sender: address,                     // 发送者地址
        input_description: String,           // 输入描述
        input_data: I,                       // 输入数据（泛型）
    }

    struct CoinInputInfo has copy, drop, store {  // 定义代币输入信息结构体，具有 copy、drop、store 能力
        coin_symbol: String,                 // 代币符号
        coin_type: String,                   // 代币类型
        amount: DecimalValue,                // 金额（十进制值）
    }

    struct AgentInputInfo has copy, drop, store {  // 定义代理输入信息结构体，具有 copy、drop、store 能力
        sender: address,                     // 发送者地址
        input_data_json: String,             // 输入数据的 JSON 表示
    }

    struct AgentInputInfoV2 has copy, drop, store {  // 定义代理输入信息 V2 结构体，具有 copy、drop、store 能力
        sender: address,                     // 发送者地址
        input_data: Any,                     // 输入数据（任意类型）
        //TODO add input coin info            // 注释：待办事项：添加代币输入信息
    }

    public fun new_agent_input<I>(               // 定义公开函数：创建新的代理输入
        sender: address,                     // 发送者地址
        input_description: String,           // 输入描述
        input_data: I,                       // 输入数据
    ): AgentInput<I> {                       // 返回 AgentInput<I> 类型
        AgentInput {                         // 创建并返回 AgentInput 实例
            sender,                          // 发送者
            input_description,               // 输入描述
            input_data,                      // 输入数据
        }
    }

    public fun new_coin_input_info(              // 定义公开函数：创建新的代币输入信息
        coin_symbol: String,                 // 代币符号
        coin_type: String,                   // 代币类型
        amount: DecimalValue,                // 金额
    ): CoinInputInfo {                       // 返回 CoinInputInfo 类型
        CoinInputInfo {                      // 创建并返回 CoinInputInfo 实例
            coin_symbol,                     // 代币符号
            coin_type,                       // 代币类型
            amount,                          // 金额
        }
    }

    public fun get_sender<I>(input: &AgentInput<I>): address {  // 定义公开函数：获取发送者地址
        input.sender                         // 返回输入中的发送者地址
    }

    public fun get_input_description<I>(input: &AgentInput<I>): &String {  // 定义公开函数：获取输入描述
        &input.input_description             // 返回输入描述的引用
    }

    public fun get_input_data<I>(input: &AgentInput<I>): &I {  // 定义公开函数：获取输入数据
        &input.input_data                    // 返回输入数据的引用
    }

    public fun unpack<I>(input: AgentInput<I>): (address, String, I) {  // 定义公开函数：解包代理输入
        let AgentInput { sender, input_description, input_data } = input;  // 解构 AgentInput
        (sender, input_description, input_data)  // 返回发送者地址、输入描述和输入数据
    }

    public fun to_agent_input_info<I>(input: &AgentInput<I>): AgentInputInfo {  // 定义公开函数：转换为 AgentInputInfo
        AgentInputInfo {                     // 创建并返回 AgentInputInfo 实例
            sender: input.sender,            // 发送者地址
            input_data_json: string::utf8(json::to_json(&input.input_data)),  // 将输入数据转换为 JSON 字符串
        }
    }

    public fun to_agent_input_info_v2<I: copy + drop + store>(input: AgentInput<I>): AgentInputInfoV2 {  // 定义公开函数：转换为 AgentInputInfoV2
        AgentInputInfoV2 {                   // 创建并返回 AgentInputInfoV2 实例
            sender: input.sender,            // 发送者地址
            input_data: copyable_any::pack(input.input_data),  // 将输入数据打包为 Any 类型
        }
    }

    public fun get_sender_from_info(info: &AgentInputInfo): address {  // 定义公开函数：从 AgentInputInfo 获取发送者地址
        info.sender                          // 返回发送者地址
    }

    public fun get_sender_from_info_v2(info: &AgentInputInfoV2): address {  // 定义公开函数：从 AgentInputInfoV2 获取发送者地址
        info.sender                          // 返回发送者地址
    }

    public fun get_input_data_from_info(info: &AgentInputInfo): &String {  // 定义公开函数：从 AgentInputInfo 获取输入数据 JSON
        &info.input_data_json                // 返回输入数据 JSON 的引用
    }

    public fun get_input_data_from_info_v2(info: &AgentInputInfoV2): &Any {  // 定义公开函数：从 AgentInputInfoV2 获取输入数据
        &info.input_data                     // 返回输入数据（Any 类型）的引用
    }

    #[test_only]
    public fun new_agent_input_info_for_test<I: copy + drop + store>(sender: address, input_data: I): AgentInputInfoV2 {  // 定义仅测试函数：为测试创建 AgentInputInfoV2
        AgentInputInfoV2 {                   // 创建并返回 AgentInputInfoV2 实例
            sender,                          // 发送者地址
            input_data: copyable_any::pack(input_data),  // 将输入数据打包为 Any 类型
        }
    }
}