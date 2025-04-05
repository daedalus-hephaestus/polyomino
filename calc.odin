package polyomino

import "core:thread"
import "core:sync"
import "core:fmt"

IsValid :: enum {
	UNCHECKED,
	YES,
	NO
}

QueueItem :: struct {
	poly: Polyomino,
	field: Field,
	is_valid: IsValid
}

Queue :: struct {
	list: [dynamic]QueueItem,
	size: int,
	index: u128,
	count: u128,
	checked: u128,
	print: u128,
	thread_count: int,
	wait_group: sync.Wait_Group,
	counting_done: sync.Barrier
}

init_queue :: proc(size: int, thread_count: int, index: u128, print: u128, length: int = -1) -> Queue {
	res : Queue
	res.size = size
	res.thread_count = thread_count
	res.index = index
	res.print = print

	sync.barrier_init(&res.counting_done, thread_count + 1)
	sync.wait_group_add(&res.wait_group, thread_count)

	tmp := length > size ? starting_polyomino(size, int(index)) : starting_polyomino(size)
	defer destroy_polyomino(&tmp)

	for i in 0..<thread_count {
		append(&res.list, QueueItem{ poly = copy_polyomino(tmp) })
		inc_polyomino(&tmp)
	}
	return res
}

destroy_queue :: proc(queue: ^Queue) {
	for &i in queue.list {
		destroy_polyomino(&i.poly)
		destroy_field(i.field)
	}
	delete(queue.list)
}

print_queue :: proc(queue: Queue) {
	for i in queue.list do fmt.printfln("%b - %v", i.poly.bin, i.is_valid)
}

process_poly :: proc(queue: ^Queue, mutex: ^sync.Mutex, id: int) {
	// run while the current count is less than the maximum index
	for queue.count <= queue.index {
		cur := queue.list[id] // the queue item this thread is allowed to work on
	
		// checks if the given polyomino is free, and saves the generated field to the queue
		free : bool
		destroy_field(queue.list[id].field)
		queue.list[id].field, free = valid_free_polyomino(cur.poly, queue.size)
		queue.list[id].is_valid = free ? .YES	: .NO

		// pauses until all other threads are done with their polyomino
		sync.wait_group_done(&queue.wait_group)
		// waits until the reader has added the valid polyominoes
		sync.barrier_wait(&queue.counting_done)

		// closes the thread when the index is reached
		if queue.count >= queue.index do break

		// increment this thread's polyomino as many times as there are threads
		for i in 0..<queue.thread_count do inc_polyomino(&queue.list[id].poly)
	}
}

read_queue :: proc(queue: ^Queue, mutex: ^sync.Mutex) {
	outer: for queue.count <= queue.index {
		// wait for all of the threads to finish their polyominoes
		sync.wait_group_wait(&queue.wait_group)

		// loops through the queue list
		for queue_item in queue.list {
			queue.checked += 1 // increment the checked counter

			// if the checked polyomino is valid
			if queue_item.is_valid == .YES {
				queue.count += 1

				// if this is the last polyomino
				if queue.count == queue.index {
					fmt.printfln("\033[uchecked: %v, found: %v", queue.checked, queue.count)
					fmt.printfln("\033[0JNo. %v", queue.count)
					print_field(queue_item.field)
					sync.barrier_wait(&queue.counting_done)
					break outer	
				}

				// prints the found polyomino
				if queue.print > 0 && queue.count % queue.print == 0 {
					fmt.printfln("\033[0JNo. %v", queue.count)
					print_field(queue_item.field)
				}
			}
			fmt.printfln("\033[uchecked: %v, found: %v", queue.checked, queue.count)
		}
		// tell all of the threads to start calculating again
		sync.wait_group_add(&queue.wait_group, queue.thread_count)
		// tell all of the threads that counting is done
		sync.barrier_wait(&queue.counting_done)
	}
}

calc_polyomino :: proc(size: int, thread_count: int, index: u128, print: u128) {
	threads : [dynamic]^thread.Thread
	mutex : sync.Mutex
	queue := init_queue(size, thread_count, index, print)
	defer destroy_queue(&queue)

	for i in 0..<thread_count {
		append(&threads, thread.create_and_start_with_poly_data3(
			&queue,
			&mutex,
			i,
			process_poly
		))
	}

	reader := thread.create_and_start_with_poly_data2(&queue, &mutex, read_queue)
	defer thread.destroy(reader)

	thread.join_multiple(..threads[:])
	thread.join(reader)

	for t in threads do thread.destroy(t)
	delete(threads)
}

calc_length_free :: proc(size: int, thread_count: int, length: u128) {
	threads : [dynamic]^thread.Thread
	mutex : sync.Mutex
	queue := init_queue(size, thread_count, length, 0, int(length))
	defer destroy_queue(&queue)

	for i in 0..<thread_count {
		append(&threads, thread.create_and_start_with_poly_data3(
			&queue,
			&mutex,
			i,
			process_length_free
		))
	}

	thread.join_multiple(..threads[:])
	for t in threads do thread.destroy(t)
	delete(threads)
}

process_length_free :: proc(queue: ^Queue, mutex: ^sync.Mutex, id: int) {
	for {
		length := get_polyomino_len(queue.list[id].poly)
		if length > int(queue.index) do break

		tmp_field, is_valid := valid_free_polyomino(queue.list[id].poly, queue.size)
		defer destroy_field(tmp_field)

		sync.lock(mutex)
		queue.checked += 1
		if is_valid do queue.count += 1
		fmt.printfln("\033[uchecked: %v, found: %v of length %v", queue.checked, queue.count, queue.index)
		sync.unlock(mutex)
		for i in 0..<queue.thread_count do inc_polyomino(&queue.list[id].poly)
	}
}

calc_length_fixed :: proc(size: int, thread_count: int, length: u128) {
	threads : [dynamic]^thread.Thread
	mutex : sync.Mutex
	queue := init_queue(size, thread_count, length, 0, int(length))
	defer destroy_queue(&queue)

	for i in 0..<thread_count {
		append(&threads, thread.create_and_start_with_poly_data3(
			&queue,
			&mutex,
			i,
			process_length_fixed
		))
	}

	thread.join_multiple(..threads[:])
	for t in threads do thread.destroy(t)
	delete(threads)
}

process_length_fixed :: proc(queue: ^Queue, mutex: ^sync.Mutex, id: int) {
	for {
		length := get_polyomino_len(queue.list[id].poly)
		if length > int(queue.index) do break

		tmp_field, is_valid := valid_polyomino(queue.list[id].poly, queue.size)
		defer destroy_field(tmp_field)

		sync.lock(mutex)
		queue.checked += 1
		if is_valid == .NONE do queue.count += 1
		fmt.printfln("\033[uchecked: %v, found: %v of length %v", queue.checked, queue.count, queue.index)
		sync.unlock(mutex)
		for i in 0..<queue.thread_count do inc_polyomino(&queue.list[id].poly)
	}
}
