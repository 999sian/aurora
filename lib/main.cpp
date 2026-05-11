#include <aurora/main.h>
#undef main

#if defined(_WIN32)
#include <SDL3/SDL.h>
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>

int main(int argc, char** argv) {
  return SDL_RunApp(argc, argv, aurora_main, nullptr);
}
#else
#include <SDL3/SDL_main.h>

int main(int argc, char** argv) {
  return aurora_main(argc, argv);
}
#endif
