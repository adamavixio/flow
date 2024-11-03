pub const Error = error{
    TagNameNotFound,
    TagTypeNotFound,

    TransformTraitNotFound,
    TransformTraitNotFunction,
    TransformResultNotError,
    TransformResultNotPointer,
};
