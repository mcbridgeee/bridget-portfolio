module.exports = function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy('src/style.css');
  eleventyConfig.addPassthroughCopy('src/*.png');
  return {
    dir: {
      input: 'src',
      includes: '_includes',
      layouts: '_includes/layouts',
      output: '_site',
    },
    templateFormats: ['njk', 'md', 'html'],
    pathPrefix: '/bridget-portfolio/',
  };
};
