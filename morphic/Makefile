.PHONY: test out.json stream

test: out.json
	cat out.json | jq '.timings | .[] | .function, .specializations[0].total_clock_nanos/1e6'

out.json: stream
	MORPHIC_PROFILE_PATH=out.json perf record -g --call-graph dwarf ./stream

stream: stream.mor rbtree.mor
	morphic build \
		--profile-record-rc \
	  --profile Stream.test3 \
		--profile Stream.test4 \
		--profile Stream.test_rb_mul_aux \
		--profile Stream.test_rb_mul \
		--profile Stream.test_rb_mul_s_il \
		--profile Stream.test_rb_mul_il \
		--profile RB.of_array \
		--profile RB.seekUp_ \
		--profile RB.seekDown_ \
		--profile RB.pathLeft \
		--profile RB.pathRight \
		--profile RB.pathUp \
		stream.mor
