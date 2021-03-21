{
    var tinycolor = require('tinycolor2');
    const isNotNullOrUndefined = (input) => input !== null && input !== undefined;
    const toColor = ({type = 'FILL', color, operator, defaultOperator = '='}) => {
      return {
        type,
        operator,
        defaultOperator,
        color,
      }
    };

    function toRgb(value) {
      const color = tinycolor(value);
      return color.toRgb();
    }

    const rgbVal = (value) => {
      return value.includes('%') ? value * 255 : value;
    };

    const toUnit = (value, type) => ({ value, type });

    const toOperation = (xywhArr, {value}, operator, defaultOperator = '=') => {
      return xywhArr.map(xywh => {
        const type = ((input) => {
          const xywh = input.toLowerCase();
          switch (xywh) {
            case 'x':
              return 'MOVE_X'
            case 'y':
              return 'MOVE_Y'
            case 'w':
              return 'WIDTH'
            case 'h':
              return 'HEIGHT'
          }
        })(xywh);

        return {
          type,
          operator,
          defaultOperator,
          value,
        }
      })
    }

    // top / right / bottom / right operation, f.e. for defining corner radius
    // values (2 4 2 2)
    const toCornerRadius = (type, valueStr) => {
      const values = valueStr.split(' ').filter(item => item !== '');
      const [topRightRadius, bottomRightRadius, bottomLeftRadius, topLeftRadius] = values;

      if (values.length === 1)
        return { cornerRadius: values[0] }
      else if (values.length === 2)
        return {
          topRightRadius,
          bottomRightRadius,
          bottomLeftRadius: values[0],
          topLeftRadius: values[1],
        }
      else if (values.length === 3)
        return {
          topRightRadius,
          bottomRightRadius,
          bottomLeftRadius,
          topLeftRadius: values[1],
        }

      return {
        topRightRadius,
        bottomRightRadius,
        bottomLeftRadius,
        topLeftRadius,
      }
    }

    const toBlendMode = mode => {
      const blendMode = mode.toUpperCase();
      return {
        type: 'BLEND_MODE',
        blendMode,
      }
    }

    const toVisible = visible => {
      return {
        type: 'VISIBILITY',
        visible
      }
    }

    const toOpacity = (value, operator = null, defaultOperator = '=') => {
      const numValue = parseFloat(value.replace('%', ''), 10);
      const opacity = Number.isInteger(numValue) ? numValue / 100 : numValue;
      return {
        type: 'OPACITY',
        operator,
        defaultOperator,
        opacity,
      };
    }

    const toStroke = (obj) => {
      return obj
    }

    // any order is allowed, but only once
    // tweaked from https://gist.github.com/nedzadarek/b0bf9aaaefd084be4f411a6767eee7fa
    // SO topic: https://stackoverflow.com/a/37137486
    function disallowDuplicates(elements){
    	if (elements < 1) return false;

      // count the amount of items
      const keyCount = elements.reduce((acc, el) => {
        const { key } = el;
        const count = acc[el.key] || 0;
        return {...acc, [key]: count + 1}
      }, {})
      // check if any of the items are > 1. If so, return false
      const isValid = !Object.values(keyCount).some(el => el > 1);

      return isValid;
    }
}

// input = command _ ? ',' command / command
// command = groupAction / numericAction
// // Actions
// groupAction= 'bdc'/'bdw'/'bd'/'fs'/'cr'/'lh'/'tc'/'tc'/'tc'/'tc'/'c'/'f'/'o'/'n'/'v'
// numericAction = _ combinedAction:combinedAction _ operator:operator* _ value:integer+ {
// 	const defaultOperator = '+'
// 	return {
//     	combinedAction,
//         operator: operator.length ? operator : defaultOperator,
//         value: value.join('')
//     }
// }

// Colors
start = args:(action separator*)+ extraCharacters { return args.map((v) => v[0]) }
  /  action
action = fill / xywh / cornerRadius / layerActions / stroke
fill = 'f'i _ operator:plusOrMinus? _ color:color { return toColor({type: 'FILL', color, operator}) }
  / 'f'i color:color { return toColor({type: 'FILL', color}) }
  // remove fill without specifying color, f.e. f -
  / 'f'i _ operator:'-' { return toColor({type: 'FILL', operator}) }
  / color:color { return toColor({type: 'FILL', color}) }

// strokeWeight _ color _ strokeAlign
// color _ strokeAlign
// strokeAlign

// color _ strokeAlign _ strokeWeight
// color _ strokeWeight _ strokeAlign
// strokeAlign _ strokeWeight


// stroke = 's'i _ strokeWeight:unit? _ color:color? _ strokeAlign:[ico]? { return toStroke({type: 'STROKE', color, strokeWeight, strokeAlign }) }
//   / 's'i _ color:color? _ strokeWeight:unit? _ strokeAlign:[ico]? { return toStroke({type: 'STROKE', color, strokeWeight, strokeAlign }) }
//   / 's'i _ strokeAlign:[ico]? _ color:color? _ strokeWeight:unit? { return toStroke({type: 'STROKE', color, strokeWeight, strokeAlign }) }
//   / 's'i _ color:color? _ strokeWeight:unit? { return toStroke({type: 'STROKE', color, strokeWeight, strokeAlign }) }
//   / 's'i _ operator:'-' { return toStroke({type: 'STROKE', operator}) }

// all fields optional where any order is allowed, but only once
stroke = 's'i __ matches:(elements:(
    strokeWeight:unit _ { return { key: 'strokeWeight', value: { strokeWeight } } }
    / color:color _ { return { key: 'color', value: { color: color } } }
    / operator:operator _ { return { key: 'operator', value: { operator: operator } } }
    / strokeAlign:[ico] _ {
      const map = {i: 'INSIDE', c: 'CENTER', o: 'OUTSIDE'};
      return { key: 'align', value: { strokeAlign: map[strokeAlign] } }
    }
  )+
  &{ return disallowDuplicates(elements) } // validate input (keys are only permitted once)
  { return elements.map(el => el.value) }  // use the value (strip the key from the output)
) { return {
  type: 'STROKE',
  ...matches.reduce((acc, match) => ({...acc, ...match}), {})
} }
  / 's'i _ operator:'-' { return toStroke({type: 'STROKE', operator}) }

xywh = xywh:XYWH _ operator:operator _ value:unit { return toOperation(xywh, value, operator) }
  / xywh:XYWH _ value:unit  { return toOperation(xywh, value, null, '=') }
layerActions = 'l' _ mode:BLEND_MODE { return toBlendMode(mode) }
  / 'l' _ value:SHOW_HIDE { return toVisible(value) }
  / [lo] _ value:numOrPercent { return toOpacity(value) }
  / [lo] _ operator:operator _ value:numOrPercent { return toOpacity(value, operator) }
cornerRadius = type:'cr' values:$(__ unit)+ { return toCornerRadius(type, values) }
unit = number:number type:'px' { return number }
  / number:number
pctUnit = number:number type:'%' { return toUnit(number, type) }
pxOrPctUnit = pctUnit / unit

SHOW_HIDE = 'show'i { return true }
  / 'hide'i { return false }
BLEND_MODE = 'color'i / 'color burn'i / 'color dodge'i / 'darken'i / 'difference'i / 'exclusion'i / 'hue'i / 'hard light'i / 'lighten'i / 'linear burn'i / 'linear dodge'i / 'luminosity'i / 'multiply'i / 'normal'i / 'overlay'i / 'saturation'i / 'screen'i / 'soft light'i
XYWH = [xwyh]i+;

color = colorRGB / colorHSL / colorHex
colorHex = c:$('#' colorHex3 colorHex3?) { return toRgb(c); }
colorHex3 = hexChar hexChar hexChar
colorRGB = ('rgba' / 'rgb') '(' _ r:numOrPercent ',' _ g:numOrPercent ',' _ b:numOrPercent ','? _ a:number? _ ')' {
    const alpha = isNotNullOrUndefined(a) ? a : 1;
    return toRgb(`rgba(${rgbVal(r)}, ${rgbVal(g)}, ${rgbVal(b)}, ${isNotNullOrUndefined(a) ? a : 1})`);
}
colorHSL = ('hsla' / 'hsl') '(' _ h:number ',' _ s:percentage ',' _ l:percentage ','? _ a:number? _ ')' {
    const alpha = isNotNullOrUndefined(a) ? a : 1;
    return toRgb(`hsla(${h}, ${s}, ${l}, ${alpha})`);
}

//  Generic
hexChar = [0-9a-fA-F]
numOrPercent = percentage / number
percentage = $(number '%')
number = $([0-9]+ ('.' [0-9]+)?)
plusOrMinus = '+' / '-'

// Misc
separator = _ '/' _ { return null }
combinedAction = [lrtbwhaxy]*
operator = [\/+\-*%#=]
integer = digits:[0-9]+ { return digits.join('') }
digit = [0-9]

extraCharacters
  = .* { return true }
// optional whitespace
_  = [ \t\r\n]*
// mandatory whitespace
__ = [ \t\r\n]+
