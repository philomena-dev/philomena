import { AutocompletableInput } from '../input';
import { propertyTypeOperators, searchTypeToPropertiesMap } from './maps';

const propertiesSyntaxRegExp =
  /^(?<property_name>[a-z\d_]+)(?<operator_syntax>\.(?<operator>[a-z]*))?(?<value_syntax>:(?<value>.*))?$/;

interface MatchedPropertyParts {
  propertyName: string;
  hasOperatorSyntax: boolean;
  hasValueSyntax: boolean;
  operator?: string;
  value?: string;
}

function parsePropertyParts(term: string): MatchedPropertyParts | null {
  propertiesSyntaxRegExp.lastIndex = 0;

  const match = propertiesSyntaxRegExp.exec(term);

  if (!match?.groups) {
    return null;
  }

  return {
    propertyName: match.groups.property_name,
    hasOperatorSyntax: Boolean(match.groups.operator_syntax),
    hasValueSyntax: Boolean(match.groups.value_syntax),
    operator: match.groups.operator,
    value: match.groups.value,
  };
}

export function matchProperties(input: AutocompletableInput, activeTerm: string): string[] {
  const propertiesMap = searchTypeToPropertiesMap.get(input.element.name);
  const parsedTermParts = propertiesMap && parsePropertyParts(activeTerm);

  if (!propertiesMap || !parsedTermParts) {
    return [];
  }

  const { hasOperatorSyntax, hasValueSyntax, propertyName, operator, value } = parsedTermParts;

  // If both operator and value aren't typed by the user yet, then we just need to find all prefix-matched property
  // names from the mapping.
  if (!hasOperatorSyntax && !hasValueSyntax) {
    return Array.from(propertiesMap.keys()).filter(suggestedPropertyName =>
      suggestedPropertyName.startsWith(propertyName),
    );
  }

  const targetPropertyTypeOrValues = propertiesMap.get(propertyName);

  // No properties matched, nothing to suggest.
  if (!targetPropertyTypeOrValues) {
    return [];
  }

  // First, we need to handle simple case of property having limited list of values it could query.
  if (Array.isArray(targetPropertyTypeOrValues)) {
    // Properties which only could contain specific list of values (like special values in my:* property or boolean
    // properties) could not use any operators. In this case we just don't suggest anything, since property is likely
    // to be invalid.
    if (hasOperatorSyntax) {
      return [];
    }

    return targetPropertyTypeOrValues
      .filter(suggestedValue => !value || suggestedValue.startsWith(value))
      .map(suggestedValue => `${propertyName}:${suggestedValue}`);
  }

  // When user already started typing value of the property, then stop suggesting anything.
  if (value) {
    return [];
  }

  const availableOperators = propertyTypeOperators.get(targetPropertyTypeOrValues) || [];

  // In case we have operators to suggest, try to find and show them first.
  const suggestionsWithOperators = availableOperators
    .filter(suggestedOperator => !operator || suggestedOperator.startsWith(operator))
    .map(suggestedOperator => `${propertyName}.${suggestedOperator}:`);

  // If user haven't started typing operator yet, then also suggest the variant without any operators.
  if (!hasOperatorSyntax) {
    suggestionsWithOperators.unshift(`${propertyName}:`)
  }

  return suggestionsWithOperators;
}
