set -e

mkdir -p bench-output

############################# Preparations

# Lean / Binaries
make -j$(nproc)

# filtered SpMV
(for nonzeros in 2000000; do
	echo data/filtered-spmv-$nonzeros.db
done) | xargs make -j$(nproc)

# TACO
(for size in 0.0001 0.0003 0.0007 0.001 0.003 0.007 0.01 0.03 0.07 0.1 0.3 0.5; do
	echo data/taco-s$size.db
done) | xargs make -j$(nproc)

# TPC-H
(for size in x0.01 x0.025 x0.05 x0.1 x0.25 x0.5 x1 x2 x4; do
	echo data/TPC-H-$size.db
done) | xargs make -j$(nproc)

# WCOJ
(for size in x1 x3 x10 x30 x100 x300 x1000 x3000 x10000; do
	echo data/wcoj-csv-$size data/wcoj-$size.db
done) | xargs make -j$(nproc)


############################# Benchmarks

# filtered SpMV
for nonzeros in 2000000; do
	for db in duckdb etch sqlite; do
		echo run-filtered-spmv-$nonzeros-$db

		# warm up
		make run-filtered-spmv-$nonzeros-$db >/dev/null
		make run-filtered-spmv-$nonzeros-$db >/dev/null

		rm -f bench-output/run-wcoj-$nonzeros-$db.txt
		for i in `seq 5`; do
			make run-filtered-spmv-$nonzeros-$db >>bench-output/run-filtered-spmv-$nonzeros-$db.txt
		done
	done
done

# TACO
for size in 0.0001 0.0003 0.0007 0.001 0.003 0.007 0.01 0.03 0.07 0.1 0.3 0.5; do
	echo run-taco-s$size

	# warm up
	make run-taco-s$size >/dev/null
	make run-taco-s$size >/dev/null

	rm -f bench-output/run-taco-s$size.txt
	for i in `seq 5`; do
		make run-taco-s$size >>bench-output/run-taco-s$size.txt
	done
done

# TPC-H Q5
for size in x0.01 x0.025 x0.05 x0.1 x0.25 x0.5 x1 x2 x4; do
	dbs='duckdb duckdbforeign etch sqlite'

	for db in $dbs; do
		echo run-tpch-$size-q5-$db

		# warm up
		make run-tpch-$size-q5-$db >/dev/null
		make run-tpch-$size-q5-$db >/dev/null

		rm -f bench-output/run-tpch-$size-q5-$db.txt
		for i in `seq 5`; do
			# echo run-tpch-$size-q5-$db time $i
			make run-tpch-$size-q5-$db >>bench-output/run-tpch-$size-q5-$db.txt
		done
	done
	sed -n 's/^q2 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-tpch-$size-q5-duckdb.txt | awk '{x+=$0}END{print "duckdb:",x/NR}'
	sed -n 's/^q2 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-tpch-$size-q5-duckdbforeign.txt | awk '{x+=$0}END{print "duckdbforeign:",x/NR}'
	sed -n 's/^q5 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-tpch-$size-q5-etch.txt | awk '{x+=$0}END{print "etch:",x/NR}'
	sed -n 's/^q2 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-tpch-$size-q5-sqlite.txt | awk '{x+=$0}END{print "sqlite:",x/NR}'
done

# TPC-H Q9
for size in x0.01 x0.025 x0.05 x0.1 x0.25 x0.5 x1 x2 x4; do
	dbs='duckdb duckdbforeign etch sqlite'

	for db in $dbs; do
		echo run-tpch-$size-q9-$db

		# warm up
		make run-tpch-$size-q9-$db >/dev/null
		make run-tpch-$size-q9-$db >/dev/null

		rm -f bench-output/run-tpch-$size-q9-$db.txt
		for i in `seq 5`; do
			# echo run-tpch-$size-q9-$db time $i
			make run-tpch-$size-q9-$db >>bench-output/run-tpch-$size-q9-$db.txt
		done
	done
	sed -n 's/^q2 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-tpch-$size-q9-duckdb.txt | awk '{x+=$0}END{print "duckdb:",x/NR}'
	sed -n 's/^q2 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-tpch-$size-q9-duckdbforeign.txt | awk '{x+=$0}END{print "duckdbforeign:",x/NR}'
	sed -n 's/^q9 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-tpch-$size-q9-etch.txt | awk '{x+=$0}END{print "etch:",x/NR}'
	sed -n 's/^q2 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-tpch-$size-q9-sqlite.txt | awk '{x+=$0}END{print "sqlite:",x/NR}'
done

# WCOJ
for size in x1 x3 x10 x30 x100 x300 x1000 x3000 x10000; do
	dbs='duckdb etch sqlite'
	if [[ $size = x300 ]]; then
		dbs='duckdb etch'
	elif [[ $size = x1000 || $size = x3000 || $size = x10000 ]]; then
		dbs='etch'
	fi

	for db in $dbs; do
		echo run-wcoj-$size-$db

		# warm up
		make run-wcoj-$size-$db >/dev/null
		make run-wcoj-$size-$db >/dev/null

		rm -f bench-output/run-wcoj-$size-$db.txt
		for i in `seq 5`; do
			# echo run-wcoj-$size-$db time $i
			make run-wcoj-$size-$db >>bench-output/run-wcoj-$size-$db.txt
		done
	done

	if [[ $dbs =~ duckdb ]]; then
		sed -n 's/^q2 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-wcoj-$size-duckdb.txt | awk '{x+=$0}END{print "duckdb:",x/NR}'
	fi
	if [[ $dbs =~ etch ]]; then
		sed -n 's/^wcojx1000 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-wcoj-$size-etch.txt | awk '{x+=$0}END{print "etch:",x/NR}'
	fi
	if [[ $dbs =~ sqlite ]]; then
		sed -n 's/^q2 took (s): real \([^ ]*\)s.*/\1/p' <bench-output/run-wcoj-$size-sqlite.txt | awk '{x+=$0}END{print "sqlite:",x/NR}'
	fi
done
