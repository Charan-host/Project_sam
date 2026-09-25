const categories = {
  DSA: ['Arrays', 'Linked Lists', 'Stacks', 'Queues', 'Trees', 'Graphs', 'Sorting', 'Searching', 'Dynamic Programming', 'Hashing'],
  Programming: ['Algorithms', 'Complexity', 'Functions', 'Recursion', 'Data Types', 'Debugging', 'Memory', 'Testing', 'Compilation', 'Design'],
  OOP: ['Classes', 'Inheritance', 'Polymorphism', 'Encapsulation', 'Abstraction', 'Interfaces', 'SOLID', 'Patterns', 'Constructors', 'Exceptions'],
  DBMS: ['Normalization', 'Transactions', 'Indexing', 'Keys', 'ER Models', 'Concurrency', 'Storage', 'Recovery', 'Views', 'Transactions'],
  'Operating Systems': ['Processes', 'Threads', 'Scheduling', 'Deadlocks', 'Memory', 'Paging', 'File Systems', 'Security', 'I/O', 'Virtualization'],
  'Computer Networks': ['OSI', 'TCP/IP', 'Routing', 'HTTP', 'DNS', 'Security', 'Transport', 'Ethernet', 'Wireless', 'Addressing'],
  Aptitude: ['Percentages', 'Profit and Loss', 'Time and Work', 'Probability', 'Averages', 'Ratios', 'Permutations', 'Number Systems', 'Speed', 'Algebra'],
  Python: ['Syntax', 'Collections', 'Functions', 'OOP', 'Iterators', 'Errors', 'Modules', 'Testing', 'Performance', 'Standard Library'],
  SQL: ['SELECT', 'Joins', 'Aggregates', 'Subqueries', 'Window Functions', 'Indexes', 'Constraints', 'Transactions', 'Views', 'Optimization'],
  'Machine Learning': ['Regression', 'Classification', 'Clustering', 'Features', 'Evaluation', 'Trees', 'Neural Networks', 'Regularization', 'Data Prep', 'Deployment'],
};

function seedQuestions() {
  return Object.entries(categories).flatMap(([category, topics]) => topics.map((topic, index) => ({
    question: `${category}: Which statement best describes ${topic}?`,
    options: [
      `${topic} is primarily used to organize or solve a related engineering problem.`,
      `${topic} can only be used for displaying user interface text.`,
      `${topic} always requires a network connection to work.`,
      `${topic} is unrelated to software development.`,
    ],
    correctAnswer: 'A',
    explanation: `${topic} is a core ${category} concept and is used to organize or solve related engineering problems.`,
    category,
    topic,
    difficulty: index % 3 === 0 ? 'Easy' : index % 3 === 1 ? 'Medium' : 'Hard',
  })));
}

module.exports = { seedQuestions, categories };
