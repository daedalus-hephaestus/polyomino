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

init_queue :: proc(size: int, thread_count: int, index: u128, print: u128) -> Queue {
	res : Queue
	res.size = size
	res.thread_count = thread_count
	res.index = index
	res.print = print

	sync.barrier_init(&res.counting_done, thread_count + 1)
	sync.wait_group_add(&res.wait_group, thread_count)

	tmp := starting_polyomino(size)
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
	for queue.count <= queue.index {
		// run tests here
		cur := queue.list[id]
		free : bool
		queue.list[id].field, free = valid_free_polyomino(cur.poly, queue.size)

		if free {
			queue.list[id].is_valid = .YES	
		} else {
			queue.list[id].is_valid = .NO
		}
		sync.wait_group_done(&queue.wait_group)
		sync.barrier_wait(&queue.counting_done)
		if queue.count >= queue.index do break
		for i in 0..<queue.thread_count {
			inc_polyomino(&queue.list[id].poly)
		}
	}
}

read_queue :: proc(queue: ^Queue, mutex: ^sync.Mutex) {
	outer: for queue.count <= queue.index {
		sync.wait_group_wait(&queue.wait_group)

		for queue_item in queue.list {
			queue.checked += 1
			if queue_item.is_valid == .YES {
				queue.count += 1

				if queue.count == queue.index {
					fmt.printfln("\033[uchecked: %v, found: %v", queue.checked, queue.count)
					fmt.printfln("\033[0JNo. %v", queue.count)
					print_field(queue_item.field)
					sync.barrier_wait(&queue.counting_done)
					break outer	
				}
				if queue.print > 0 && queue.count % queue.print == 0 {
					fmt.printfln("\033[0JNo. %v", queue.count)
					print_field(queue_item.field)
				}
			}
			fmt.printfln("\033[uchecked: %v, found: %v", queue.checked, queue.count)
		}
		sync.wait_group_add(&queue.wait_group, queue.thread_count)
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
