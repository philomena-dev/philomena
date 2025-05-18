import { AutocompletableInput } from '../input';
import { propertyTypeOperators, searchTypeToPropertiesMap, tagProperty } from './maps';
import { type LocalAutocompleter } from '../../utils/local-autocompleter';
import { type TagSuggestion } from '../../utils/suggestions-model';

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

export class SuggestedProperty {
  /**
   * Name of the property.
   */
  readonly name: string;
  readonly type: symbol | null = null;
  operator: string | null;
  value: string | null;

  constructor(name: string, type: symbol | null = null, operator: string | null = null, value: string | null = null) {
    this.name = name;
    this.type = type;
    this.operator = operator;
    this.value = value;
  }

  toString(): string {
    let resultValue = this.name;

    if (this.operator) {
      resultValue += `.${this.operator}`;
    }

    // Making sure to include the colon when operator or value is provided. When empty operator is passed, then it
    // indicates that colon should be included.
    if (this.operator !== null || this.value !== null) {
      resultValue += ':';
    }

    if (this.value) {
      resultValue += this.value;
    }

    return resultValue;
  }
}

function resolveCanonicalTagNameFromSuggestion(suggestion: TagSuggestion): string {
  if (typeof suggestion.canonical === 'string') {
    return suggestion.canonical;
  }

  return suggestion.canonical
    .map(matchPart => (typeof matchPart === 'string' ? matchPart : matchPart.matched))
    .join('');
}

/**
 * Create the list of suggested properties from an active term.
 * @param input Input matching was called from. Input is required to determine which list of properties should be
 * suggested. It's also used for suggesting tags inside tag-properties.
 * @param activeTerm Actual term parsed from the search query. This is the string which will be used to find relevant
 * properties.
 * @param autocomplete Instance of {@link LocalAutocompleter} used for several properties related to tags.
 * @return List of suggested properties for displaying to the user.
 */
export function matchProperties(
  input: AutocompletableInput,
  activeTerm: string,
  autocomplete: LocalAutocompleter,
): SuggestedProperty[] {
  const propertiesMap = searchTypeToPropertiesMap.get(input.element.name);
  const parsedTermParts = propertiesMap && parsePropertyParts(activeTerm);

  if (!propertiesMap || !parsedTermParts) {
    return [];
  }

  const { hasOperatorSyntax, hasValueSyntax, propertyName, operator, value } = parsedTermParts;

  // If both operator and value aren't typed by the user yet, then we just need to find all prefix-matched property
  // names from the mapping.
  if (!hasOperatorSyntax && !hasValueSyntax) {
    return Array.from(propertiesMap.keys())
      .filter(suggestedPropertyName => suggestedPropertyName.startsWith(propertyName))
      .map(suggestedPropertyName => new SuggestedProperty(suggestedPropertyName));
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
      .map(suggestedValue => new SuggestedProperty(propertyName, null, null, suggestedValue));
  }

  // For the properties which accept tags as values, make additional autocomplete call.
  if (targetPropertyTypeOrValues === tagProperty && value) {
    const matchedTagsResult = autocomplete
      .matchPrefix(value, input.maxSuggestions)
      .map(
        tagSuggestion =>
          new SuggestedProperty(
            propertyName,
            targetPropertyTypeOrValues,
            null,
            resolveCanonicalTagNameFromSuggestion(tagSuggestion),
          ),
      );

    if (!matchedTagsResult.length) {
      matchedTagsResult.push(new SuggestedProperty(propertyName, targetPropertyTypeOrValues, null, value));
    }

    return matchedTagsResult;
  }

  // When user already started typing value of the property, then stop suggesting anything.
  if (value) {
    return [];
  }

  const availableOperators = propertyTypeOperators.get(targetPropertyTypeOrValues) || [];

  // In case we have operators to suggest, try to find and show them first.
  const suggestionsWithOperators = availableOperators
    .filter(suggestedOperator => !operator || suggestedOperator.startsWith(operator))
    .map(suggestedOperator => new SuggestedProperty(propertyName, targetPropertyTypeOrValues, suggestedOperator));

  // If user haven't started typing operator yet, then also suggest the variant without any operators.
  if (!hasOperatorSyntax) {
    suggestionsWithOperators.unshift(new SuggestedProperty(propertyName, targetPropertyTypeOrValues, ''));
  }

  return suggestionsWithOperators;
}
