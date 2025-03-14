module nuwa_framework::ring_buffer {
    use std::vector;                          // 导入标准库中的向量模块
    use std::option::{Self, Option};         // 导入标准库中的选项模块，并引入 Option 类型

    const ErrorEmptyBuffer: u64 = 1;          // 定义错误码：缓冲区为空
    const ErrorZeroCapacity: u64 = 2;         // 定义错误码：容量为零
    const ErrorInvalidIndex: u64 = 3;         // 定义错误码：无效索引

    /// A ring buffer implementation that reuses the underlying vector
    /// when it reaches its capacity.           // 注释：环形缓冲区实现，当达到容量时重用底层向量
    struct RingBuffer<E: copy + drop> has copy, store, drop {  // 定义环形缓冲区结构体，具有 copy、store、drop 能力，泛型 E 需支持 copy 和 drop
        /// The underlying vector to store elements  // 注释：用于存储元素的底层向量
        buffer: vector<E>,                    // 缓冲区向量，存储元素
        /// The maximum capacity of the buffer  // 注释：缓冲区的最大容量
        capacity: u64,                        // 最大容量
        /// The current number of elements in the buffer  // 注释：缓冲区中的当前元素数量
        size: u64,                            // 当前大小
        /// The index of the head (first element) in the buffer  // 注释：缓冲区中头部（第一个元素）的索引
        head: u64,                            // 头部索引
        /// The index of the tail (where next element will be inserted) in the buffer  // 注释：缓冲区中尾部（下一个元素插入位置）的索引
        tail: u64,                            // 尾部索引
    }
    
    /// Create a new ring buffer with the specified capacity  // 注释：创建具有指定容量的新环形缓冲区
    public fun new<E: copy + drop>(capacity: u64, default_value: E): RingBuffer<E> {  // 定义公开函数：创建新环形缓冲区
        assert!(capacity > 0, ErrorZeroCapacity);  // 断言：确保容量大于 0，否则抛出容量为零错误
        
        let buffer = vector[];                // 初始化空的缓冲区向量
        let i = 0;                            // 初始化索引
        while (i < capacity) {                // 循环填充默认值，直到达到指定容量
            vector::push_back(&mut buffer, default_value);  // 将默认值添加到缓冲区向量
            i = i + 1;                        // 索引递增
        };

        RingBuffer {                          // 返回新的环形缓冲区实例
            buffer,                           // 底层缓冲区向量
            capacity,                         // 最大容量
            size: 0,                          // 初始大小为 0
            head: 0,                          // 初始头部索引为 0
            tail: 0,                          // 初始尾部索引为 0
        }
    }

    /// Returns true if the buffer is empty    // 注释：如果缓冲区为空，返回 true
    public fun is_empty<E: copy + drop>(ring_buffer: &RingBuffer<E>): bool {  // 定义公开函数：检查缓冲区是否为空
        ring_buffer.size == 0                 // 返回当前大小是否为 0
    }

    /// Returns true if the buffer is full     // 注释：如果缓冲区已满，返回 true
    public fun is_full<E: copy + drop>(ring_buffer: &RingBuffer<E>): bool {  // 定义公开函数：检查缓冲区是否已满
        ring_buffer.size == ring_buffer.capacity  // 返回当前大小是否等于最大容量
    }

    /// Returns the current number of elements in the buffer  // 注释：返回缓冲区中的当前元素数量
    public fun size<E: copy + drop>(ring_buffer: &RingBuffer<E>): u64 {  // 定义公开函数：获取缓冲区当前大小
        ring_buffer.size                      // 返回当前大小
    }

    /// Returns the maximum capacity of the buffer  // 注释：返回缓冲区的最大容量
    public fun capacity<E: copy + drop>(ring_buffer: &RingBuffer<E>): u64 {  // 定义公开函数：获取缓冲区容量
        ring_buffer.capacity                  // 返回最大容量
    }

    /// Push an item to the ring buffer.       // 注释：将元素推入环形缓冲区
    /// If the buffer is full, the oldest item will be overwritten.  // 注释：如果缓冲区已满，最旧的元素将被覆盖
    /// Returns the replaced item if any.      // 注释：如果有元素被替换，返回被替换的元素
    public fun push<E: copy + drop>(ring_buffer: &mut RingBuffer<E>, item: E): Option<E> {  // 定义公开函数：推入元素到缓冲区
        let old_item = if (is_full(ring_buffer)) {  // 如果缓冲区已满
            // If buffer is full, save the item at head position  // 注释：如果缓冲区已满，保存头部位置的元素
            let head_item = *vector::borrow(&ring_buffer.buffer, ring_buffer.head);  // 获取头部元素
            // Replace head item with new item  // 注释：用新元素替换头部元素
            *vector::borrow_mut(&mut ring_buffer.buffer, ring_buffer.head) = item;  // 将新元素写入头部位置
            // Move head forward               // 注释：头部向前移动
            ring_buffer.head = if (ring_buffer.head + 1 == ring_buffer.capacity) {  // 如果头部到达容量边界
                0                                 // 重置为 0（循环）
            } else {
                ring_buffer.head + 1              // 否则递增
            };
            option::some(head_item)           // 返回被替换的旧元素
        } else {                              // 如果缓冲区未满
            // If buffer is not full          // 注释：如果缓冲区未满
            *vector::borrow_mut(&mut ring_buffer.buffer, ring_buffer.tail) = item;  // 将新元素写入尾部位置
            ring_buffer.size = ring_buffer.size + 1;  // 增加当前大小
            option::none()                    // 返回无替换元素
        };

        // Move tail forward                 // 注释：尾部向前移动
        ring_buffer.tail = if (ring_buffer.tail + 1 == ring_buffer.capacity) {  // 如果尾部到达容量边界
            0                                     // 重置为 0（循环）
        } else {
            ring_buffer.tail + 1                  // 否则递增
        };
        old_item                                  // 返回替换的元素（如果有）
    }

    /// Pop the oldest item from the ring buffer.  // 注释：从环形缓冲区弹出最旧的元素
    /// Returns None if the buffer is empty.   // 注释：如果缓冲区为空，返回 None
    public fun pop<E: copy + drop>(ring_buffer: &mut RingBuffer<E>): Option<E> {  // 定义公开函数：从缓冲区弹出元素
        if (is_empty(ring_buffer)) {          // 如果缓冲区为空
            return option::none()             // 返回 None
        };
        
        // Get item at head position         // 注释：获取头部位置的元素
        let item = *vector::borrow(&ring_buffer.buffer, ring_buffer.head);  // 获取头部元素
        ring_buffer.size = ring_buffer.size - 1;  // 减少当前大小
        
        if (!is_empty(ring_buffer)) {         // 如果缓冲区不为空
            // Move head forward             // 注释：头部向前移动
            ring_buffer.head = if (ring_buffer.head + 1 == ring_buffer.capacity) {  // 如果头部到达容量边界
                0                             // 重置为 0（循环）
            } else {
                ring_buffer.head + 1          // 否则递增
            };
        } else {                              // 如果缓冲区变为空
            // Reset pointers when empty     // 注释：当缓冲区为空时重置指针
            ring_buffer.head = 0;             // 头部重置为 0
            ring_buffer.tail = 0;             // 尾部重置为 0
        };
        
        option::some(item)                    // 返回弹出的元素
    }

    /// Get a reference to the oldest item without removing it.  // 注释：获取最旧元素的引用，不移除
    /// Aborts if the buffer is empty.        // 注释：如果缓冲区为空则中止
    public fun peek<E: copy + drop>(ring_buffer: &RingBuffer<E>): &E {  // 定义公开函数：查看最旧元素
        assert!(!is_empty(ring_buffer), ErrorEmptyBuffer);  // 断言：确保缓冲区不为空，否则抛出空缓冲区错误
        vector::borrow(&ring_buffer.buffer, ring_buffer.head)  // 返回头部元素的引用
    }

    /// Clear the ring buffer, removing all elements  // 注释：清除环形缓冲区，移除所有元素
    public fun clear<E: copy + drop>(ring_buffer: &mut RingBuffer<E>) {  // 定义公开函数：清空缓冲区
        ring_buffer.size = 0;                 // 将当前大小设置为 0
        ring_buffer.head = 0;                 // 重置头部索引为 0
        ring_buffer.tail = 0;                 // 重置尾部索引为 0
    }

    /// Returns a vector containing all elements in the ring buffer in FIFO order.  // 注释：返回包含所有元素的向量，按先进先出顺序
    /// The ring buffer remains unchanged.    // 注释：环形缓冲区保持不变
    public fun to_vector<E: copy + drop>(ring_buffer: &RingBuffer<E>): vector<E> {  // 定义公开函数：将缓冲区转换为向量
        let result = vector::empty();         // 初始化空的向量用于存储结果
        if (is_empty(ring_buffer)) {          // 如果缓冲区为空
            return result                     // 返回空向量
        };
        
        let count = 0;                        // 初始化计数器
        let current = ring_buffer.head;       // 从头部索引开始
        
        while (count < ring_buffer.size) {    // 遍历缓冲区中的所有元素
            vector::push_back(&mut result, *vector::borrow(&ring_buffer.buffer, current));  // 将当前元素加入结果向量
            current = if (current + 1 == ring_buffer.capacity) {  // 如果当前索引到达容量边界
                0                             // 重置为 0（循环）
            } else {
                current + 1                   // 否则递增
            };
            count = count + 1;                // 计数器递增
        };
        
        result                                // 返回结果向量
    }

    /// Get a reference to the element at the specified index.  // 注释：获取指定索引处元素的引用
    /// Index 0 refers to the oldest element (head), and index size-1 refers to the newest element.  // 注释：索引 0 表示最旧元素（头部），索引 size-1 表示最新元素
    /// Aborts if the index is out of bounds.  // 注释：如果索引超出范围则中止
    public fun get<E: copy + drop>(ring_buffer: &RingBuffer<E>, index: u64): &E {  // 定义公开函数：获取指定索引的元素
        assert!(index < ring_buffer.size, ErrorInvalidIndex);  // 断言：确保索引在有效范围内，否则抛出无效索引错误
        let actual_index = if (ring_buffer.head + index >= ring_buffer.capacity) {  // 如果索引超出容量
            // Wrap around if we exceed capacity  // 注释：如果超过容量则环绕
            ring_buffer.head + index - ring_buffer.capacity  // 计算环绕后的实际索引
        } else {
            ring_buffer.head + index          // 否则直接计算实际索引
        };
        vector::borrow(&ring_buffer.buffer, actual_index)  // 返回实际索引处元素的引用
    }

    #[test]
    fun test_new_ring_buffer() {              // 定义测试函数：测试新环形缓冲区的创建
        let buffer = new<u64>(5, 0);          // 创建容量为 5 的环形缓冲区，默认值为 0
        assert!(is_empty(&buffer), 0);        // 断言：确保缓冲区为空
        assert!(!is_full(&buffer), 0);        // 断言：确保缓冲区未满
        assert!(size(&buffer) == 0, 0);       // 断言：确保当前大小为 0
        assert!(capacity(&buffer) == 5, 0);   // 断言：确保容量为 5
    }

    #[test]
    fun test_push_full() {                    // 定义测试函数：测试推入元素到满缓冲区
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        push(&mut buffer, 10);                // 推入元素 10
        push(&mut buffer, 20);                // 推入元素 20
        push(&mut buffer, 30);                // 推入元素 30
        assert!(is_full(&buffer), 0);         // 断言：确保缓冲区已满
        let item = *peek(&buffer);            // 查看最旧元素
        assert!(item == 10, 0);               // 断言：确保最旧元素是 10
    }

    #[test]
    fun test_push_pop_basic() {               // 定义测试函数：测试基本的推入和弹出操作
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        
        // Push elements                    // 注释：推入元素
        let replaced = push(&mut buffer, 10);  // 推入元素 10
        assert!(option::is_none(&replaced), 0);  // 断言：没有元素被替换
        assert!(size(&buffer) == 1, 0);       // 断言：当前大小为 1
        
        replaced = push(&mut buffer, 20);     // 推入元素 20
        assert!(option::is_none(&replaced), 0);  // 断言：没有元素被替换
        assert!(size(&buffer) == 2, 0);       // 断言：当前大小为 2
        
        replaced = push(&mut buffer, 30);     // 推入元素 30
        assert!(option::is_none(&replaced), 0);  // 断言：没有元素被替换
        assert!(size(&buffer) == 3, 0);       // 断言：当前大小为 3
        assert!(is_full(&buffer), 0);         // 断言：缓冲区已满
        
        // Pop elements in FIFO order       // 注释：按先进先出顺序弹出元素
        let popped = pop(&mut buffer);        // 弹出最旧元素
        assert!(option::is_some(&popped), 0);  // 断言：弹出成功
        assert!(option::extract(&mut popped) == 10, 0);  // 断言：弹出元素是 10
        assert!(size(&buffer) == 2, 0);       // 断言：当前大小为 2
        
        popped = pop(&mut buffer);            // 弹出下一个元素
        assert!(option::extract(&mut popped) == 20, 0);  // 断言：弹出元素是 20
        assert!(size(&buffer) == 1, 0);       // 断言：当前大小为 1
        
        popped = pop(&mut buffer);            // 弹出最后一个元素
        assert!(option::extract(&mut popped) == 30, 0);  // 断言：弹出元素是 30
        assert!(size(&buffer) == 0, 0);       // 断言：当前大小为 0
        assert!(is_empty(&buffer), 0);        // 断言：缓冲区为空
        
        // Pop from empty buffer            // 注释：从空缓冲区弹出
        popped = pop(&mut buffer);            // 尝试从空缓冲区弹出
        assert!(option::is_none(&popped), 0);  // 断言：返回 None
    }

    #[test]
    fun test_circular_overwrite() {           // 定义测试函数：测试环形覆盖行为
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        
        // Fill the buffer                 // 注释：填充缓冲区
        push(&mut buffer, 10);                // 推入元素 10
        push(&mut buffer, 20);                // 推入元素 20
        push(&mut buffer, 30);                // 推入元素 30
        assert!(is_full(&buffer), 0);         // 断言：缓冲区已满
        
        // Push more elements, which should overwrite the oldest ones  // 注释：推入更多元素，应覆盖最旧元素
        let replaced = push(&mut buffer, 40);  // 推入元素 40
        assert!(option::is_some(&replaced), 0);  // 断言：有元素被替换
        assert!(option::extract(&mut replaced) == 10, 0);  // 断言：被替换元素是 10
        
        replaced = push(&mut buffer, 50);     // 推入元素 50
        assert!(option::extract(&mut replaced) == 20, 0);  // 断言：被替换元素是 20
        
        // Buffer should now contain [30, 40, 50]  // 注释：缓冲区现在应包含 [30, 40, 50]
        assert!(size(&buffer) == 3, 0);       // 断言：当前大小为 3
        
        // Verify contents by popping       // 注释：通过弹出验证内容
        let popped = pop(&mut buffer);        // 弹出元素
        assert!(option::extract(&mut popped) == 30, 0);  // 断言：弹出元素是 30
        
        popped = pop(&mut buffer);            // 弹出元素
        assert!(option::extract(&mut popped) == 40, 0);  // 断言：弹出元素是 40
        
        popped = pop(&mut buffer);            // 弹出元素
        assert!(option::extract(&mut popped) == 50, 0);  // 断言：弹出元素是 50
        
        assert!(is_empty(&buffer), 0);        // 断言：缓冲区为空
    }

    #[test]
    fun test_peek() {                         // 定义测试函数：测试查看功能
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        
        push(&mut buffer, 10);                // 推入元素 10
        push(&mut buffer, 20);                // 推入元素 20
        
        // Peek should return the oldest element without removing it  // 注释：查看应返回最旧元素，不移除
        let item = peek(&buffer);             // 查看最旧元素
        assert!(*item == 10, 0);              // 断言：最旧元素是 10
        assert!(size(&buffer) == 2, 0);       // 断言：大小未变，仍为 2
        
        // Pop and verify the same element is returned  // 注释：弹出并验证返回相同元素
        let popped = pop(&mut buffer);        // 弹出元素
        assert!(option::extract(&mut popped) == 10, 0);  // 断言：弹出元素是 10
        
        // Peek at the next element         // 注释：查看下一个元素
        item = peek(&buffer);                 // 查看最旧元素
        assert!(*item == 20, 0);              // 断言：最旧元素是 20
    }

    #[test]
    #[expected_failure(abort_code = ErrorEmptyBuffer)]
    fun test_peek_empty() {                   // 定义测试函数：测试查看空缓冲区（预期失败）
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        // This should abort with ErrorEmptyBuffer  // 注释：这应因空缓冲区错误而中止
        let _ = peek(&buffer);                // 尝试查看空缓冲区
    }

    #[test]
    fun test_clear() {                        // 定义测试函数：测试清空功能
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        
        push(&mut buffer, 10);                // 推入元素 10
        push(&mut buffer, 20);                // 推入元素 20
        push(&mut buffer, 30);                // 推入元素 30
        
        clear(&mut buffer);                   // 清空缓冲区
        
        assert!(is_empty(&buffer), 0);        // 断言：缓冲区为空
        assert!(size(&buffer) == 0, 0);       // 断言：当前大小为 0
    }

    #[test]
    fun test_push_pop_cycle() {               // 定义测试函数：测试推入和弹出循环行为
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        
        // Fill and empty the buffer multiple times to test the circular behavior  // 注释：多次填充和清空缓冲区以测试循环行为
        let i = 0;                            // 初始化循环计数器
        while (i < 10) {                      // 循环 10 次
            push(&mut buffer, i);             // 推入当前计数器值
            
            if (i >= 3) {                     // 如果计数器大于等于 3
                // Buffer should start replacing elements  // 注释：缓冲区应开始替换元素
                assert!(is_full(&buffer), 0); // 断言：缓冲区已满
            };
            i = i + 1;                        // 计数器递增
        };
        
        // Buffer should now contain [7, 8, 9]  // 注释：缓冲区现在应包含 [7, 8, 9]
        assert!(size(&buffer) == 3, 0);       // 断言：当前大小为 3
        
        let popped = pop(&mut buffer);        // 弹出元素
        assert!(option::extract(&mut popped) == 7, 0);  // 断言：弹出元素是 7
        
        popped = pop(&mut buffer);            // 弹出元素
        assert!(option::extract(&mut popped) == 8, 0);  // 断言：弹出元素是 8
        
        popped = pop(&mut buffer);            // 弹出元素
        assert!(option::extract(&mut popped) == 9, 0);  // 断言：弹出元素是 9
        
        assert!(is_empty(&buffer), 0);        // 断言：缓冲区为空
    }

    #[test]
    fun test_complex_sequence() {             // 定义测试函数：测试复杂操作序列
        let buffer = new<u64>(5, 0);          // 创建容量为 5 的环形缓冲区，默认值为 0
        
        // Push some elements               // 注释：推入一些元素
        push(&mut buffer, 10);                // 推入元素 10
        push(&mut buffer, 20);                // 推入元素 20
        push(&mut buffer, 30);                // 推入元素 30
        
        // Pop one                         // 注释：弹出一个元素
        let popped = pop(&mut buffer);        // 弹出元素
        assert!(option::extract(&mut popped) == 10, 0);  // 断言：弹出元素是 10
        
        // Push more                       // 注释：推入更多元素
        push(&mut buffer, 40);                // 推入元素 40
        push(&mut buffer, 50);                // 推入元素 50
        push(&mut buffer, 60);                // 推入元素 60
        
        // Buffer should now contain [20, 30, 40, 50, 60]  // 注释：缓冲区现在应包含 [20, 30, 40, 50, 60]
        assert!(size(&buffer) == 5, 0);       // 断言：当前大小为 5
        assert!(is_full(&buffer), 0);         // 断言：缓冲区已满
        
        // Push one more to trigger replacement  // 注释：再推入一个元素以触发替换
        let replaced = push(&mut buffer, 70);  // 推入元素 70
        assert!(option::extract(&mut replaced) == 20, 0);  // 断言：被替换元素是 20
        
        // Buffer should now contain [30, 40, 50, 60, 70]  // 注释：缓冲区现在应包含 [30, 40, 50, 60, 70]
        let item = peek(&buffer);             // 查看最旧元素
        assert!(*item == 30, 0);              // 断言：最旧元素是 30
        
        // Pop all and verify              // 注释：弹出所有元素并验证
        popped = pop(&mut buffer);            // 弹出元素
        assert!(option::extract(&mut popped) == 30, 0);  // 断言：弹出元素是 30
        
        popped = pop(&mut buffer);            // 弹出元素
        assert!(option::extract(&mut popped) == 40, 0);  // 断言：弹出元素是 40
        
        popped = pop(&mut buffer);            // 弹出元素
        assert!(option::extract(&mut popped) == 50, 0);  // 断言：弹出元素是 50
        
        popped = pop(&mut buffer);            // 弹出元素
        assert!(option::extract(&mut popped) == 60, 0);  // 断言：弹出元素是 60
        
        popped = pop(&mut buffer);            // 弹出元素
        assert!(option::extract(&mut popped) == 70, 0);  // 断言：弹出元素是 70
        
        assert!(is_empty(&buffer), 0);        // 断言：缓冲区为空
    }

    #[test]
    fun test_to_vector() {                    // 定义测试函数：测试转换为向量功能
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        
        // Test empty buffer               // 注释：测试空缓冲区
        let elements = to_vector(&buffer);    // 将缓冲区转换为向量
        assert!(vector::is_empty(&elements), 0);  // 断言：向量为空
        
        // Test partially filled buffer    // 注释：测试部分填充的缓冲区
        push(&mut buffer, 10);                // 推入元素 10
        push(&mut buffer, 20);                // 推入元素 20
        elements = to_vector(&buffer);        // 将缓冲区转换为向量
        assert!(vector::length(&elements) == 2, 0);  // 断言：向量长度为 2
        assert!(*vector::borrow(&elements, 0) == 10, 0);  // 断言：第一个元素是 10
        assert!(*vector::borrow(&elements, 1) == 20, 0);  // 断言：第二个元素是 20
        
        // Test full buffer                // 注释：测试满缓冲区
        push(&mut buffer, 30);                // 推入元素 30
        elements = to_vector(&buffer);        // 将缓冲区转换为向量
        assert!(vector::length(&elements) == 3, 0);  // 断言：向量长度为 3
        assert!(*vector::borrow(&elements, 0) == 10, 0);  // 断言：第一个元素是 10
        assert!(*vector::borrow(&elements, 1) == 20, 0);  // 断言：第二个元素是 20
        assert!(*vector::borrow(&elements, 2) == 30, 0);  // 断言：第三个元素是 30
        
        // Test after wraparound           // 注释：测试环绕后的缓冲区
        push(&mut buffer, 40);                // 推入元素 40（触发覆盖）
        elements = to_vector(&buffer);        // 将缓冲区转换为向量
        assert!(vector::length(&elements) == 3, 0);  // 断言：向量长度为 3
        assert!(*vector::borrow(&elements, 0) == 20, 0);  // 断言：第一个元素是 20
        assert!(*vector::borrow(&elements, 1) == 30, 0);  // 断言：第二个元素是 30
        assert!(*vector::borrow(&elements, 2) == 40, 0);  // 断言：第三个元素是 40
    }

    #[test]
    fun test_get() {                          // 定义测试函数：测试获取指定索引元素功能
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        
        // Push some elements               // 注释：推入一些元素
        push(&mut buffer, 10);                // 推入元素 10
        push(&mut buffer, 20);                // 推入元素 20
        push(&mut buffer, 30);                // 推入元素 30
        
        // Test accessing elements by index  // 注释：测试按索引访问元素
        let item = get(&buffer, 0);           // 获取索引 0 的元素（最旧）
        assert!(*item == 10, 0);              // 断言：元素是 10
        
        item = get(&buffer, 1);               // 获取索引 1 的元素
        assert!(*item == 20, 0);              // 断言：元素是 20
        
        item = get(&buffer, 2);               // 获取索引 2 的元素（最新）
        assert!(*item == 30, 0);              // 断言：元素是 30
        
        // Test after wraparound           // 注释：测试环绕后的情况
        push(&mut buffer, 40);                // 推入元素 40（触发覆盖）
        
        item = get(&buffer, 0);               // 获取索引 0 的元素（最旧）
        assert!(*item == 20, 0);              // 断言：元素是 20
        
        item = get(&buffer, 1);               // 获取索引 1 的元素
        assert!(*item == 30, 0);              // 断言：元素是 30
        
        item = get(&buffer, 2);               // 获取索引 2 的元素（最新）
        assert!(*item == 40, 0);              // 断言：元素是 40
    }

    #[test]
    #[expected_failure(abort_code = ErrorInvalidIndex)]
    fun test_get_out_of_bounds() {            // 定义测试函数：测试获取超出范围的索引（预期失败）
        let buffer = new<u64>(3, 0);          // 创建容量为 3 的环形缓冲区，默认值为 0
        push(&mut buffer, 10);                // 推入元素 10
        // This should abort with ErrorInvalidIndex  // 注释：这应因无效索引错误而中止
        let _ = get(&buffer, 1);              // 尝试获取超出范围的索引 1
    }
}