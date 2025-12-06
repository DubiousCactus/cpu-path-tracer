![Test scene rendered afteer Book 1 implementation](./render.jpg)

# Ray Tracing in a Weekend (and the next week, and hopefully not for the rest of my life)

This is a Zig (v0.15.2) implementation of [Ray Tracing in a Weekend](https://raytracing.github.io).
I followed the reference implementation from the book, but also focused on implementing
it the Zig way.


## Improvements

This implementation comes with several minor improvements to the reference
implementation in the book:

- [x] Exporting the output image into a file directly, with buffered writing for efficiency.
- [ ] Exporting to compressed image formats.
- [x] Parallelism with threads.
- [ ] Scene loading from gLTF files.
- [ ] Live render in a window
