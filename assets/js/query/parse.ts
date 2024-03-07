import { matchAll, matchAny, matchNone, matchNot } from './boolean';
import { AstMatcher, TokenList } from './types';

export function parseTokens(lexicalArray: TokenList): AstMatcher {
  const operandStack: AstMatcher[] = [];

  lexicalArray.forEach((token, i) => {
    if (token === 'not_op') {
      return;
    }

    let intermediate: AstMatcher;

    if (typeof token === 'string') {
      const op2 = operandStack.pop();
      const op1 = operandStack.pop();

      if (typeof op1 === 'undefined' || typeof op2 === 'undefined') {
        throw new Error('Missing operand.');
      }

      if (token === 'and_op') {
        intermediate = matchAll(op1, op2);
      }
      else {
        intermediate = matchAny(op1, op2);
      }
    }
    else {
      intermediate = token;
    }

    if (lexicalArray[i + 1] === 'not_op') {
      operandStack.push(matchNot(intermediate));
    }
    else {
      operandStack.push(intermediate);
    }
  });

  if (operandStack.length > 1) {
    throw new Error('Missing operator.');
  }

  const op1 = operandStack.pop();

  if (typeof op1 === 'undefined') {
    return matchNone();
  }

  return op1;
}
