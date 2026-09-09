const gulp = require("gulp");
const workbox = require("workbox-build");
const terser = require("gulp-terser");
const cleanCSS = require("gulp-clean-css");
const pipeline = require("readable-stream").pipeline;

// 压缩站点全部 JS/CSS。必须在 generate-service-worker 之前运行：
// injectManifest 按文件内容计算预缓存 revision 哈希，压缩后再生成
// 清单才能保证 Service Worker 缓存的哈希与实际文件一致。
gulp.task("minify-js", () => {
  return pipeline(
    gulp.src("./public/**/*.js"),
    terser(),
    gulp.dest("./public"),
  );
});

gulp.task("minify-css", () => {
  return pipeline(
    gulp.src("./public/**/*.css"),
    cleanCSS(),
    gulp.dest("./public"),
  );
});

gulp.task("generate-service-worker", () => {
  return workbox.injectManifest({
    swSrc: "./sw-template.js",
    swDest: "./public/sw.js",
    globDirectory: "./public",
    globPatterns: ["**/*.{css,js,json,xml,svg,ttf,woff,eot}"],
    globIgnores: ["**/*.html"],
    modifyURLPrefix: {
      "": "./",
    },
  });
});

// sw.js 在 injectManifest 之后才生成，且不在预缓存清单内，故单独压缩。
gulp.task("uglify", function () {
  return pipeline(
    gulp.src("./public/sw.js"),
    terser(),
    gulp.dest("./public"),
  );
});

gulp.task(
  "build",
  gulp.series(
    gulp.parallel("minify-js", "minify-css"),
    "generate-service-worker",
    "uglify",
  ),
);
