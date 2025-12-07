module.exports = function (_eleventyConfig) {
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
