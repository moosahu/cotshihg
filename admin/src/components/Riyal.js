import React from 'react';

/** Renders an amount with the official Saudi Riyal symbol */
export default function Riyal({ amount, style }) {
  return (
    <span style={style}>
      {amount} <i className="icon-saudi_riyal_new" />
    </span>
  );
}
