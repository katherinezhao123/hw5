# Running the tests:
#   make test        all the tests
#   make part1       only Part 1's tests (expressions and environments)
#   ...
#   make part7       only Part 7's tests (whole programs)
#   make clean       remove generated Python files, pictures and build files
#
# To run the tests for a single step, for example Step 2.3:
#   runghc -itest test/Spec.hs --match "Step 2.3"

SPEC = runghc -itest test/Spec.hs

test:
	$(SPEC)

part1:
	$(SPEC) --match "Part 1:"
part2:
	$(SPEC) --match "Part 2:"
part3:
	$(SPEC) --match "Part 3:"
part4:
	$(SPEC) --match "Part 4:"
part5:
	$(SPEC) --match "Part 5:"
part6:
	$(SPEC) --match "Part 6:"
part7:
	$(SPEC) --match "Part 7:"

clean:
	rm -f *.hi *.o test/*.hi test/*.o
	find python -name '*.png' -delete
	find python -name '*.py' ! -name plotter_runtime.py ! -name nextdraw_backend.py ! -name mock_nextdraw.py -delete
	rm -rf python/__pycache__

.PHONY: test part1 part2 part3 part4 part5 part6 part7 clean
