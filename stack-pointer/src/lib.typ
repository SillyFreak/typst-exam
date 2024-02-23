#import "@preview/polylux:0.3.1": only

#import "effects.typ": *

/// Sequence item with type `"step"`: a single step at which execution state can be inspected.
/// A step can have any fields associated with it that can be used to visualize the execution state.
///
/// - ..args (dictionary): exclusively named arguments to be added to the step
/// -> array
#let step(..args) = {
  assert(args.pos().len() == 0, message: "only named arguments allowed")
  let args = args.named()
  assert("type" not in args, message: "type can't be used as a field in a step")
  ((type: "step", ..args),)
}

/// A template for creating functions like @@l(). This function takes effects as positional
/// parameters and step fields as named parameters. To Define a custom `l()`-like function, use
/// something like this:
/// ```typ
/// #let my-l(foo, ..args) = bare-l(foo: foo, ..args)
/// ```
/// Now `my-l()` lets you specify the `foo` field for your executions as a positional parameter.
///
/// - ..args (arguments): the effects to apply before the next step, and the fields for the next step
/// -> array
#let bare-l(..args) = {
  let effects = args.pos()
  let args = args.named()
  for effect in effects {
    effect
  }
  step(..args)
}

/// -> array
/// High-level step creating function. Emits any number of effects, followed by a single step. This
/// function takes a line number as a positional parameter, then effects as additional positional
/// parameters, and step fields as named parameters.
///
/// - line (integer): the line number to add to the step as a field
/// - ..args (arguments): the effects to apply before the next step, and the extra fields for the next step
/// -> array
#let l(line, ..args) = bare-l(line: line, ..args)

/// Sequence item-like value with type `"return-value"` for @@func(): a simulated function may
/// generate this as its last "item" to signify its return value. A function that doesn't use this
/// can simply be called by another like this:
/// ```typc
/// my-func(a, b)
/// ```
/// which will result in its sequence items being put into the sequence where it is called. A
/// function that calls `retval()` is called like this:
/// ```typc
/// let (result, ..rest) = my-func(a, b); rest
/// ```
/// here, the result given to `retval()` is destructured into its own variable, and the real items
/// are emitted so that they appear in the sequence of steps.
///
/// `retval()` being called multiple times or not as the last item is an error.
///
/// - result (any): the return value of the function
/// -> array
#let retval(result) = ((type: "return-value", result: result),)

/// A helper for writing functions that produce execution sequences. This function automatically
/// inserts @@call() and @@ret() effects. The implementation used by this function is given as a
/// closure that receives a function similar to @@l(), but which adapts the line number according to
/// the `first-line` parameter.
///
/// Usually, the first thing in a function using this will be a step to show the function call,
/// optionally preceded by @@push() effects for the parameters. The last thing may be a @@retval()
/// pseudo sequence item. If it is, then the returned array will have the return value as the
/// _first_ element.
///
/// The return effect is not part of a step generated by this function; usually the caller will add
/// a step to display the new state at the location (line number) to which execution returned.
///
/// - name (string): the name of the function; used for the call effect
/// - first-line (int): the line at which the simulated function starts
/// - callback: simulates the function, receives an `l()`-like function
/// -> array
#let func(name, first-line, callback) = {
  import "effects.typ": call, ret

  // evaluate the function
  let _l(line, ..args) = {
    if line != none and first-line != none {
      line = first-line + line
    }
    l(line, ..args)
  }
  let steps = callback(_l)

  // if there was an exit(), extract it and the value from it
  let result = if steps.last().type == "return-value" {
    (steps.remove(steps.len() - 1).result,)
  }

  // if there is exit() anywhere else, that's an error
  assert(
    steps.all(step => step.type != "return-value"),
    message: "only one exit() at the end of a function execution is allowed: " + repr(steps)
  )

  // prepend the result, if any
  result
  // assemble the final steps
  call(name)
  steps
  ret()
}

/// Simulates the given execution sequence and returns an array of states for each step in the
/// sequence. Each element of the array is a dictionary with two fields:
/// - `step`: the fields of the step (not including the type); this will often include a line number
/// - `state`: the execution state according to the executed effects. Currently, the state only
///   contains a `stack` field, which is in turn an array of stack frames with `name` and `vars`
///   fields.
///
/// In total, the returned value looks like this:
/// ```typc
/// (
///   (
///     step: (line: 1, ...),       // any step fields
///     state: (                    // currently, executuion state is only the stack
///       stack: (
///         (name: "main", vars: (  // function main is the topmost stack frame
///           foo: 1,               // local variable foo in main has value 1
///           ...                   // more local variables
///         )),
///         ...                     // more stack frames
///       )
///     )
///   ),
///   ...                           // execution states for other steps
/// )
///
/// ```
///
/// - sequence (array): an execution sequence
/// -> dictionary
#let execute(sequence) = {
  let state = (stack: ())
  let steps = ()

  for (type: t, ..rest) in sequence {
    // step
    if t == "step" {
      steps.push((
        step: rest,
        state: state,
      ))
    // effects
    } else if t == "call" {
      let (name,) = rest
      state.stack.push((name: name, vars: (:)))
    } else if t == "push" {
      let (name, value) = rest
      state.stack.last().vars.insert(name, value)
    } else if t == "assign" {
      let (name, value) = rest
      state.stack.last().vars.at(name) = value
    } else if t == "return" {
      let _ = state.stack.pop()
    // unknown
    } else {
      panic(t)
    }
  }

  steps
}
