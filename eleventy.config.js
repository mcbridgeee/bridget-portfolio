module.exports = function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy('src/style.css');
  return {
    dir: {
      input: 'src',
      includes: '_includes',
      layouts: '_includes/layouts',
      output: '_site',
    },
    templateFormats: ['njk', 'md', 'html'],
  };
};
